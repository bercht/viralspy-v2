# 01_ARQUITETURA — Stack, Infraestrutura e Decisões Técnicas

> Este documento lista decisões técnicas já travadas. Só devem ser revisitadas com motivo forte e aprovação explícita do Curt.

---

## Stack

### Backend

| Componente | Versão | Justificativa |
|-----------|--------|---------------|
| Ruby | 3.3.x | Padrão atual, mesma versão do Fifty |
| Rails | 7.1.x | Versão estável, Hotwire nativo, importmap |
| PostgreSQL | 16 | + extensão pgvector habilitada (usado em fase futura) |
| Redis | 7 | Cache + broker Sidekiq |
| Sidekiq | 7 | Background jobs, mesma stack do Fifty |

### Frontend

| Componente | Notas |
|-----------|-------|
| Tailwind CSS | Apenas utility classes — ver `02_PADROES_CODIGO.md` |
| Hotwire (Turbo + Stimulus) | Padrão Rails 7.1, SEM SPA |
| Importmap | Sem bundler (webpack/esbuild) |
| ViewComponent | Gem instalada mas **não usada no MVP** — ver decisão em `02_PADROES_CODIGO.md` |

### Gems principais

```ruby
# Autenticação/Autorização
gem 'devise'
gem 'pundit'

# Multi-tenancy
gem 'acts_as_tenant'

# Background jobs
gem 'sidekiq', '~> 7.0'

# IA
gem 'ruby-openai'           # versão travada no Gemfile.lock
gem 'anthropic'             # versão travada no Gemfile.lock
gem 'assemblyai', '~> 1.0'  # transcrição (provider AssemblyAI)
gem 'neighbor'              # pgvector wrapper (uso em Fase 2.5+)

# HTTP
gem 'httparty'

# Components
gem 'view_component'

# Desenvolvimento
gem 'dotenv-rails'
gem 'rubocop-rails-omakase'
gem 'erb_lint'

# Teste
gem 'rspec-rails'
gem 'factory_bot_rails'
gem 'webmock'
gem 'vcr'
gem 'shoulda-matchers'
gem 'faker'
```

---

## Infraestrutura

### Ambiente de produção

- **VPS Hostinger** (mesmo do Fifty): 72.60.152.144
- **Reverse proxy:** Traefik v3.1 **compartilhado** — instância única em `/opt/traefik/` no VPS
- **Network Docker externa:** `web` (todos os apps com domínio público se conectam nela)
- **CDN/WAF:** Cloudflare com TLS mode **Full (strict)**
- **Containers:** cada app tem seu próprio `docker-compose.yml` independente
- **Deploy user:** `deployer` (nunca `root`)
- **Branch strategy:** `main` → staging automático, `production` → deploy manual
- **Domínio MVP:** `viralspy.curt.com.br`

### Apps rodando no mesmo VPS (coexistência)

| App | Domínio | Status |
|-----|---------|--------|
| Fifty CRM | `fifty.com.br` | Em produção |
| Novo Marketing Imobiliário | `novomarketingimobiliario.com.br` | Em produção |
| curt.com.br | `curt.com.br` | Site pessoal/portfólio |
| ViralSpy v2 | `viralspy.curt.com.br` | **Em desenvolvimento** |

Todos compartilham Traefik, rodam em stacks Docker separadas.

### Arquitetura de containers

```
┌─────────────────────────────────────────┐
│ Traefik (reverse proxy, TLS, routing)   │
└────────────┬────────────────────────────┘
             │
    ┌────────┼──────────┬──────────┐
    ▼        ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│  web   │ │ worker │ │  db    │ │ redis  │
│(rails) │ │(sidekiq│ │ (pg16) │ │  (r7)  │
│ :3000  │ │        │ │ :5432  │ │ :6379  │
└────────┘ └────────┘ └────────┘ └────────┘
```

### Volumes persistentes

- `./tmp/postgres_data` → dados do banco
- `./tmp/redis_data` → dados Redis (AOF enabled)
- `./tmp/storage` → Active Storage local
- Backups diários via cron na VPS → bucket S3-compatible (Hostinger Object Storage)

---

## Isolamento em relação ao Fifty

**Separação absoluta:**

| Recurso | Fifty | ViralSpy v2 |
|---------|-------|-------------|
| Repositório Git | `fifty` | `viralspy-v2` |
| Rails app | Monolito próprio | Monolito próprio separado |
| Banco Postgres | DB `fifty_production` | DB `viralspy_production` |
| Redis | DB lógico 0 | DB lógico separado (2 ou 3) |
| Containers Docker | Stack `fifty` | Stack `viralspy_v2` (separada) |
| Domínio | fifty.com.br | viralspy.curt.com.br |
| Contas de billing | Stripe conta Fifty | Stripe conta separada (futuro) |

**Compartilhamento:**

| Recurso | Notas |
|---------|-------|
| VPS Hostinger | Mesmo servidor físico |
| Traefik | Mesma instância, roteia ambos domínios |
| Cloudflare | Mesma conta, DNS para ambos |

---

## Decisões arquiteturais (ADRs)

### ADR-001: Scraping via provider abstrato com Apify inicial

**Contexto:** Produto depende de scraping Instagram. Três opções: Apify, scraper próprio, híbrido.

**Decisão:** Abstração `Scraping::BaseProvider` com implementação inicial `Scraping::ApifyProvider`. Preparar caminho para `Scraping::NativeProvider` futuro sem mudar interface pública.

**Implementação (após Fase 1.3):**

- **Dois actors em sequência:**
  1. `apify/instagram-profile-scraper` → metadata do perfil (`followersCount`, `biography`, `fullName`)
  2. `apify/instagram-post-scraper` → detalhe completo de cada post
- **Modo assíncrono** com polling (não `run-sync-get-dataset-items`): POST `/runs` → poll `/actor-runs/{id}` a cada 5s → GET `/actor-runs/{id}/dataset/items`. Timeout local de 240s, aborta run em caso de timeout.
- **Classe `Scraping::Apify::Client`** wrappa HTTParty; **`Scraping::Apify::RunPoller`** faz polling com sleeper injetável; **`Scraping::Apify::Parser`** é módulo puro que converte JSON Apify → hash interno.
- **Retry apenas em erros transientes** (RateLimit, Timeout) com 1 retry e backoff 2s. Sem retry em `ProfileNotFound`, `RunFailed`, `ParseError`.
- **Tipos descartados** do array: stories, IGTV antigos (Video com `productType != "clips"`), lives — não viram `nil`, somem do array.
- **Hashtags persistidas sem `#`** (formato nativo Apify).
- **Testes:** unit specs com WebMock, integration spec com VCR cassette real de `@curtbercht`, sanitizado (token → `<APIFY_TOKEN>`, PII → `REDACTED_*`).

#### Interface pública do `Scraping::ApifyProvider`

> **Importante:** esta é a interface real do código conforme mergeada no commit `baf0a22`. Consumidores (ex: `Analyses::ScrapeStep`) devem usar esses nomes exatos — não inventar.

**Método principal:**

```ruby
scraper = Scraping::Factory.build
result = scraper.scrape_profile(handle: "natgeo", max_posts: 30)
```

- **Nome:** `scrape_profile` (não `fetch_profile_with_posts`).
- **Argumentos (kwargs):** `handle:` (String, sem `@`) e `max_posts:` (Integer).
- **Retorno:** `Scraping::Result`.

**Shape do `Scraping::Result`:**

```ruby
result.success?        # => true | false
result.failure?        # => true | false
result.error           # => String | nil
result.message         # => String | nil  (descrição do erro)
result.profile_data    # => Hash com metadata do perfil (NÃO é `.data[:profile]`)
result.posts           # => Array<Hash> com posts estruturados (NÃO é `.data[:posts]`)
```

- `profile_data` e `posts` são **métodos de primeira classe** do Result, não chaves de um hash `data`.
- Consumidores acessam diretamente: `result.posts.each { ... }`, `result.profile_data[:followers_count]`.

**Shape de `profile_data`:**

```ruby
{
  full_name: String,
  bio: String,
  followers_count: Integer,
  following_count: Integer,
  posts_count: Integer,
  profile_pic_url: String
}
```

**Shape de cada item em `posts`:**

```ruby
{
  instagram_post_id: String,
  shortcode: String,
  post_type: String,        # "reel" | "carousel" | "image"
  caption: String,
  display_url: String,
  video_url: String,        # nil se não for reel
  likes_count: Integer,
  comments_count: Integer,
  video_view_count: Integer, # nil se não for reel
  hashtags: Array<String>,   # sem "#"
  mentions: Array<String>,
  posted_at: DateTime
}
```

**Gotchas operacionais descobertos na Fase 1.3:**

- O `post-scraper` exige `username` + `directUrls` simultaneamente (400 sem `username`), mesmo quando você passa URLs diretas. Não é documentado.
- Profile-scraper usa `usernames` (plural); post-scraper usa `username` (singular). Inconsistência entre actors do mesmo publisher oficial.
- Cassettes VCR precisam ser **apagados antes de regravar** — matching padrão é por method+URI, body diferente servirá resposta antiga erroneamente.
- Pra regravar cassettes: trocar `record: :none` → `:new_episodes` em `spec/rails_helper.rb` temporariamente, rodar, auditar sanitização, reverter. Processo humano.

**Consequências:**
- ✅ Time-to-market rápido (Apify pronto)
- ✅ Troca de provider no futuro sem refactor de app
- ✅ Integration spec offline-safe (cassette commitado, ~$0.05 custo único pra gravar)
- ⚠️ Custo variável no MVP (aceitável pra validar produto) — ~$0.10/análise (2 actors)
- ⚠️ Dependência de terceiro no curto prazo
- ⚠️ Cassettes ficam stale — regravar a cada ~3 meses ou quando Apify mudar shape

**Status:** ✅ Travada (implementada e em produção a partir da Fase 1.3, commit `baf0a22`). Interface consumida pela Fase 1.5a (`Analyses::ScrapeStep`).

---

### ADR-002: LLM Gateway com OpenAI e Anthropic

**Contexto:** Necessidade de chamar múltiplos LLMs com fallback e tracking de custo.

**Decisão:** Classe `LLM::Gateway` abstrai providers. Modelos padrão por use case — configuráveis pelo usuário via ADR-013:
- Análise estruturada (extração JSON): `gpt-4o-mini` (OpenAI, default)
- Geração criativa (sugestões, playbook): `claude-sonnet-4-6` (Anthropic, default)

**Cada chamada gera registro em `LLMUsageLog`** (prompt tokens, completion tokens, cost_cents, use_case).

**Resolução de provider e chave:** via `account.llm_preferences` e `account.api_credentials` (ADR-013), não via ENV. Provider e chave API são do usuário.

**Consequências:**
- ✅ Troca de provider trivial
- ✅ Tracking de custo por tenant e use case
- ✅ Neutralidade de provider — usuário escolhe conforme preferência e custo
- ⚠️ Pricing hardcoded na UsageLogger — precisa atualizar manualmente se provider mudar preço

**Status:** ✅ Travada. Atualizada pelo ADR-013 (resolução via account, não ENV).

---

### ADR-003: Multi-tenancy via acts_as_tenant

**Contexto:** Produto é multi-tenant. Opções: schema-per-tenant, row-level isolation com Postgres RLS, gem Ruby.

**Decisão:** `acts_as_tenant` com `account_id` em todos modelos tenant-scoped. `ActsAsTenant.configure { require_tenant = true }`.

**Consequências:**
- ✅ Simples de implementar e manter
- ✅ Queries automaticamente scoped
- ⚠️ Risco de vazamento se `ActsAsTenant.without_tenant` for mal usado
- ⚠️ Não é isolamento forte como schema-per-tenant (aceitável no MVP)

**Status:** ✅ Travada.

---

### ADR-004: Sem SPA, sem React/Vue, sem jQuery

**Contexto:** Frontend moderno tem várias opções.

**Decisão:** Hotwire nativo Rails 7.1 — Turbo + Stimulus. Nada mais.

**Consequências:**
- ✅ Menor complexidade, menor superfície de bug
- ✅ Mesmo padrão do Fifty (reuso de know-how)
- ⚠️ Menos flexibilidade para UIs muito interativas (não é problema no MVP)

**Status:** ✅ Travada. Ver `02_PADROES_CODIGO.md` para regras detalhadas.

---

### ADR-005: Tailwind puro, sem CSS customizado

**Contexto:** Tailwind permite `@apply`, classes customizadas, CSS inline. Todas aumentam manutenção.

**Decisão:** Apenas utility classes diretas no HTML. Sem `@apply`. Sem `.css` customizado. Sem `<style>` tag. Sem atributo `style=""`.

**Consequências:**
- ✅ Consistência máxima, zero ambiguidade
- ✅ Renderização previsível em qualquer contexto
- ⚠️ HTML mais verboso (aceitável — trade-off conhecido do Tailwind)

**Status:** ✅ Travada.

---

### ADR-006: Encryption via ActiveRecord::Encryption

**Contexto:** Chaves API do usuário (BYOK — ADR-013), tokens Meta Graph API (ADR-012) e outros segredos de usuário precisam ser encryptados em repouso.

**Decisão:** `ActiveRecord::Encryption` padrão Rails 7+. Chaves geradas via `bin/rails db:encryption:init` e armazenadas em `credentials.yml.enc`.

**Campos encryptados atualmente:**
- `ApiCredential#encrypted_api_key` — chaves OpenAI, Anthropic e AssemblyAI do usuário (BYOK, ADR-013)

**Planejado para fases futuras:**
- `OwnProfile#meta_access_token` — token Meta Graph API (ADR-012, Fase 3.1)

**Consequências:**
- ✅ Nativo Rails, sem dependência externa
- ✅ Suporta deterministic (para busca) e non-deterministic (para storage)
- ⚠️ Mudança de chave requer migration de dados

**Status:** ✅ Travada.

---

### ADR-007: Testes com RSpec + VCR + WebMock

**Contexto:** Chamadas reais a APIs externas em testes são inviáveis.

**Decisão:**
- **WebMock** para mockar HTTP em unit specs
- **VCR** para gravar responses reais em integration specs (uma vez, commit do cassette)
- **Cassettes** ficam em `spec/fixtures/vcr_cassettes`
- Cassettes de APIs externas são sanitizados (filter_sensitive_data) para remover chaves

**Consequências:**
- ✅ Testes rodam offline, reprodutíveis
- ✅ Real API response comportamento fica documentado em cassettes
- ⚠️ Cassettes ficam stale — precisam ser regravados periodicamente

**Status:** ✅ Travada.

---

### ADR-008: Transcription com providers OpenAI e AssemblyAI, sem ffmpeg, sem vector store

**Contexto:** Pipeline de análise precisa transcrever áudio de reels do Instagram. Múltiplas decisões aninhadas: qual provider, como extrair áudio, como usar o transcript depois.

**Decisão:**

1. **Providers suportados:** dois providers alternativos, ambos implementados e funcionais.
   - `Transcription::Providers::OpenAI` usando modelo `gpt-4o-mini-transcribe`
   - `Transcription::Providers::AssemblyAI` usando API padrão
   - Abstração `Transcription::BaseProvider` unifica interface. `Transcription::Factory.build(provider:, api_key:)` instancia o correto conforme configuração do usuário.
   - **Default do sistema: AssemblyAI.** Motivo: free tier de US$ 50 no signup (~40k reels de 40s), reduz fricção no onboarding BYOK.
2. **Trade-off entre providers (informativo, sem recomendação forte):**
   - **OpenAI:** aceita MP4 direto (não precisa extrair áudio), pricing por minuto de áudio, latência ~5-10s por reel.
   - **AssemblyAI:** aceita MP4 direto, pricing por minuto de áudio, free tier generoso, latência ~8-15s por reel.
   - Ambos são equivalentes em qualidade pra PT-BR em reels de 15-60s (validado em testes informais na 1.4). Usuário escolhe conforme preferência e custo.
3. **Sem ffmpeg no MVP:** MP4 do reel é baixado via HTTP e enviado direto pra API do provider (multipart upload). Ambos os providers aceitam vídeo — extraem áudio do seu lado. Simplifica container (sem apt install ffmpeg), simplifica pipeline (sem etapa de extração).
4. **MP4 é descartado após transcrever:** zero storage de mídia de terceiros. Evita questão de direito autoral e economiza espaço. Se precisar reprocessar, baixa de novo do CDN.
5. **Vídeos > 25MB são pulados:** marca `transcript_status = skipped` com reason. Raro em reels (duração curta).
6. **Falha individual de transcrição NÃO derruba a análise:** marca `transcript_status = failed` no Post e segue o pipeline. Uma transcrição falhada não justifica abortar tudo.
7. **Sem Vector Store da OpenAI:** transcripts vão direto no prompt da AnalyzeStep junto com caption. Volume de dados por análise (12 posts selecionados × ~500 tokens) cabe folgadamente no context window de 200k do Claude Sonnet. RAG seria over-engineering.
8. **Sem pgvector no MVP:** embedding de transcripts/posts fica pra Fase 2.5 (Embeddings e Busca Semântica), quando houver volume suficiente pra justificar.
9. **Tabela de usage separada:** `TranscriptionUsageLog` distinta de `LLMUsageLog` — pricing de transcrição é em minutos de áudio, não tokens. Não misturar unidades diferentes na mesma tabela.
10. **Chave:** vem de `account.api_credentials` (ADR-013), não de ENV. Cada provider tem sua própria credential (`ApiCredential#provider` aceita `openai`, `anthropic`, `assemblyai`).

**Consequências:**
- ✅ Dois providers de transcrição implementados — usuário escolhe conforme custo e preferência
- ✅ Zero dependência de binário externo (ffmpeg) no container
- ✅ Zero acoplamento com Assistants API da OpenAI (preserva neutralidade entre OpenAI e Anthropic)
- ✅ Free tier AssemblyAI reduz fricção no onboarding BYOK — usuário não precisa adicionar cartão em OpenAI pra começar
- ⚠️ Upload de MP4 inteiro desperdiça bandwidth vs. upload de MP3 extraído (aceitável no MVP)
- ⚠️ Se provider configurado cair, análise completa com transcripts parciais

**Status:** ✅ Travada. Atualizada pelo ADR-013 (chave via account, não ENV). Atualizada na preparação da Fase 1.6a (AssemblyAI como provider alternativo e default).

---

### ADR-009: Scoring e seleção de posts em Ruby puro, dentro de cada tipo

**Contexto:** Apify retorna até 30 posts por análise (reels, carrosséis, imagens). Mandar todos pro LLM é caro e dilui qualidade dos insights. Precisa selecionar os melhores. "Melhores" não é "mais views" — reel de 2 anos tem views acumuladas que um reel de 3 dias nunca terá. Precisa score que compense o tempo.

**Decisão:**

1. **Scoring é 100% Ruby, zero IA.** Fórmula determinística, barata, roda em milissegundos.

2. **Fórmula:**
   ```
   score = (engagement / max(followers, 1)) × maturity_boost × 1_000_000

   onde:
     engagement     = likes_count + (comments_count × 3)
     days_since     = max((Time.now - posted_at) / 1.day, 0.25)
     maturity       = min(days_since / 7.0, 1.0)
     maturity_boost = 1.0 / max(maturity, 0.1)
   ```

3. **Peso de comentário = 3x like.** Comentário exige esforço maior do usuário, é sinal mais forte de ressonância.

4. **Maturity boost compensa tempo:** reel de 1 dia com 200 likes pode bater reel de 30 dias com 500 likes, porque o novo ainda está crescendo. Boost decai pra 1.0 após 7 dias.

5. **Filtros de elegibilidade (posts que NÃO recebem score):**
   - `likes_count + comments_count < 10` — evita ruído
   - `posted_at > 6.hours.ago` — muito novo, sem sinal ainda

6. **Score calculado DENTRO de cada tipo, não cross-type.** Reel compete com reel, carrossel com carrossel.

7. **Seleção top N por tipo:**
   - **Top 12 reels** *(ajustado de 8 → 12 na Fase 1.5a)*
   - Top 5 carrosséis
   - Top 3 imagens
   - Se tipo não tiver posts suficientes elegíveis, seleciona o que tem e segue.

8. **`quality_score` persistido no banco** — permite exibir ranking na UI e auditar histórico.

9. **Transparência pro usuário:** UI da Analysis mostra os top posts com score, caption preview, métricas.

**Consequências:**
- ✅ Cost-free no sentido de API (Ruby puro, zero tokens)
- ✅ Reduz custo de transcrição em ~50%
- ✅ Melhora qualidade do insight do LLM
- ⚠️ Fórmula é heurística — vai precisar calibração em beta

**Status:** ✅ Travada (implementada na Fase 1.5a). Ajustes na fórmula são permitidos dentro do `Analyses::Scoring::Formula` sem ADR nova, desde que critério de seleção top-N-por-tipo seja mantido.

---

### ADR-010: Análise LLM segmentada por tipo de conteúdo (3 chamadas) + sugestões mixadas

**Contexto:** LLM podia receber todos os posts selecionados num prompt único (1 chamada) ou 3 chamadas separadas por tipo (reels, carrosséis, imagens). Mesmo trade-off na geração de sugestões.

**Decisão:**

1. **`AnalyzeStep` faz 3 chamadas LLM separadas:**
   - `analyze_reels(top_reels + profile_metrics)` → insights específicos de formato reel
   - `analyze_carousels(top_carousels + profile_metrics)` → insights de carrossel
   - `analyze_images(top_images + profile_metrics)` → insights de imagem

2. **Se um tipo não tem posts selecionados, pula a chamada.** Sem erro.

3. **Cada chamada é independente.** Falha numa não derruba as outras.

4. **`GenerateSuggestionsStep` faz 1 chamada** recebendo todos os insights + profile_metrics. Mix padrão: 2 reels + 2 carrosséis + 1 imagem = 5 sugestões. Fallback se tipo não tem insights: preenche com reels até total=5.

5. **Prompts versionados em `app/prompts/*.erb`** — permite iterar qualidade sem rebuild.

6. **Pipeline é serial** (não paralelo). Decidido na Fase 1.5b pra simplicidade.

**Consequências:**
- ✅ Prompts focados por formato → insights qualitativamente melhores
- ✅ Resiliência: falha parcial degrada graciosamente
- ✅ Prompts editáveis sem deploy
- ⚠️ Mais latência (3 chamadas sequenciais, ~30s somados)

**Status:** ✅ Travada.

---

### ADR-011: Playbooks — Base de Conhecimento Múltipla, Versionada e com Feedback Loop

**Contexto:** Cada usuário opera em nichos distintos e precisa de bases de conhecimento separadas. As análises de concorrentes alimentam um ou mais playbooks conforme relevância definida pelo usuário. O conhecimento acumula, versiona e aprende com feedbacks — incluindo ideias geradas no Claude Project do usuário.

**Decisão:**

#### 1. `Playbook` é entidade própria, não singleton por conta

```ruby
create_table :playbooks do |t|
  t.references :account, null: false, foreign_key: true
  t.string :name, null: false              # "Marketing Imobiliário com IA"
  t.string :niche                          # descrição livre do nicho
  t.text :purpose                          # pra que serve esse playbook
  t.references :own_profile,              # perfil próprio vinculado (opcional)
    foreign_key: { to_table: :own_profiles }
  t.integer :current_version_number, default: 0
  t.timestamps
  t.index [:account_id, :name], unique: true
end
```

`own_profile` é nil para playbooks de pesquisa pura (ex: "Corretores de Imóveis" — estuda o nicho mas não tem perfil próprio vinculado).

#### 2. Análise contribui para N playbooks via junção

```ruby
create_table :analysis_playbooks do |t|
  t.references :analysis, null: false, foreign_key: true
  t.references :playbook, null: false, foreign_key: true
  t.integer :update_status, default: 0   # enum: pending | completed | failed
  t.timestamps
  t.index [:analysis_id, :playbook_id], unique: true
end
```

Ao disparar uma análise, o usuário seleciona em quais playbooks ela contribui — pode ser um, vários, ou nenhum. O `UpdatePlaybookStep` roda uma vez por entrada nessa tabela.

#### 3. Versionamento via `PlaybookVersion`

```ruby
create_table :playbook_versions do |t|
  t.references :account, null: false, foreign_key: true
  t.references :playbook, null: false, foreign_key: true
  t.integer :version_number, null: false
  t.text :content, null: false             # markdown completo da versão
  t.text :diff_summary                     # prosa: "o que mudou nessa versão"
  t.references :triggered_by_analysis,
    foreign_key: { to_table: :analyses }
  t.integer :feedbacks_incorporated_count, default: 0
  t.timestamps
  t.index [:playbook_id, :version_number], unique: true
end
```

#### 4. Feedback loop via `PlaybookFeedback`

```ruby
create_table :playbook_feedbacks do |t|
  t.references :account, null: false, foreign_key: true
  t.references :playbook, null: false, foreign_key: true
  t.text :content, null: false
  t.string :source                         # 'manual' | 'claude_project' | 'own_post_result'
  t.integer :status, default: 0           # enum: pending | incorporated | dismissed
  t.references :incorporated_in_version,
    foreign_key: { to_table: :playbook_versions }
  t.references :related_analysis,
    foreign_key: { to_table: :analyses }
  t.references :related_own_post,
    foreign_key: { to_table: :own_posts }
  t.timestamps
  t.index [:playbook_id, :status]
end
```

#### 5. Estrutura do Playbook markdown

```markdown
# Playbook — [Nome do Playbook]
## Nicho e Contexto
## Tom de Voz
## Hooks que Funcionam
## Formatos de Reel Validados
## Formatos de Carrossel Validados
## Temas com Alta Performance
## Anti-padrões (o que não funciona)
## Insights Transversais
## Evolução do Meu Perfil (se own_profile vinculado)
```

#### 6. `Analyses::UpdatePlaybookStep`

Roda ao final do pipeline para cada `AnalysisPlaybook` com `status: pending`. Recebe: insights frescos + playbook atual + feedbacks pendentes. Chama LLM via `LLM::Gateway` usando chaves e provider do usuário (ADR-013). Gera nova `PlaybookVersion`, marca feedbacks como `incorporated`.

#### 7. Export para Claude Project

Botão "Exportar Playbook" gera markdown da versão atual. Usuário faz upload no próprio Claude Project. Consultas ao agente são feitas no claude.ai do usuário — zero custo adicional de API.

**Consequências:**
- ✅ Múltiplos playbooks por conta — cada nicho, cada cliente, cada propósito
- ✅ Análise contribui pra N playbooks conforme relevância
- ✅ Playbook de pesquisa pura (sem perfil próprio) — estuda nicho sem ter presença nele
- ✅ Histórico completo de evolução do conhecimento por playbook
- ✅ Export para Claude Project — consultas ao agente no claude.ai Pro, zero custo extra
- ⚠️ `UpdatePlaybookStep` roda N vezes se análise contribui pra N playbooks — custo é do usuário (BYOK)
- ⚠️ Qualidade do playbook depende da qualidade dos insights — schema estruturado obrigatório no `AnalyzeStep`

**Status:** ✅ Travada. Implementar na Fase 2.1.

---

### ADR-012: Perfil Próprio — OwnProfile, Meta Graph API, OwnPost e Loop de Resultado

**Contexto:** O pipeline analisa concorrentes e gera sugestões, mas não sabe o que o usuário efetivamente postou nem o que funcionou. Fechar esse loop — sugestão → execução → resultado real → aprendizado — é o que transforma o produto em coach de crescimento pessoal.

**Decisão:**

#### 1. `OwnProfile` — perfil próprio do usuário

Entidade separada de `Competitor`: `Competitor` usa scraping público via Apify, `OwnProfile` usa Meta Graph API autenticada com métricas privadas.

```ruby
create_table :own_profiles do |t|
  t.references :account, null: false, foreign_key: true
  t.string :instagram_handle, null: false
  t.string :full_name
  t.text :bio
  t.text :voice_notes                      # tom de voz, expressões, o que evitar
  t.string :meta_access_token             # encryptado via ActiveRecord::Encryption (ADR-006)
  t.datetime :meta_token_expires_at
  t.datetime :meta_token_last_refreshed_at
  t.timestamps
  t.index [:account_id, :instagram_handle], unique: true
end
```

Job Sidekiq alerta quando `meta_token_expires_at < 7.days.from_now`.

#### 2. Meta Graph API — escopo de uso

Token de longa duração (60 dias, renovável). O que a Graph API entrega que scraping público não entrega: alcance real, impressões, saves, shares, plays de reel, dados de stories. Endpoints utilizados:

- `GET /me/media` — lista posts publicados
- `GET /{media_id}/insights` — métricas privadas por post
- `GET /{media_id}/insights` com métricas de stories — dados de stories enquanto ativos (24h)

Configuração: usuário cria app no Meta for Developers, adiciona próprio perfil como usuário de teste, gera token de longa duração.

#### 3. `OwnPost` — registro de cada postagem

```ruby
create_table :own_posts do |t|
  t.references :account, null: false, foreign_key: true
  t.references :own_profile, null: false, foreign_key: true
  t.string :instagram_post_id
  t.string :post_type, null: false         # 'reel' | 'carousel' | 'image' | 'story'
  t.string :permalink
  t.text :caption
  t.text :transcript
  t.integer :transcript_status, default: 0
  t.datetime :posted_at
  t.references :inspired_by_suggestion,
    foreign_key: { to_table: :content_suggestions }
  t.text :execution_notes
  t.jsonb :metrics, default: {}            # snapshot atual da Graph API
  t.datetime :metrics_last_fetched_at
  t.jsonb :metrics_history, default: []   # snapshots com timestamp (D+1, D+7, D+30)
  t.integer :performance_rating            # enum: breakthrough | good | average | flop
  t.text :performance_notes
  t.timestamps
  t.index [:account_id, :posted_at]
  t.index [:own_profile_id, :posted_at]
  t.index :instagram_post_id
end
```

`OwnPosts::FetchMetricsWorker` roda automaticamente em D+1, D+7, D+30 após `posted_at`.

#### 4. Transcrição dos próprios reels

Mesmo `Transcription::Factory` já existente. Transcript alimenta o playbook — o agente aprende tom de voz real a partir do que o usuário efetivamente fala.

#### 5. `StoryObservation` — registro manual de stories de concorrentes

Scraping de stories de concorrentes é inviável (24h, bloqueio Meta). Formulário rápido no ViralSpy:

```ruby
create_table :story_observations do |t|
  t.references :account, null: false, foreign_key: true
  t.references :competitor, null: false, foreign_key: true
  t.date :observed_on, null: false
  t.string :format           # 'poll'|'quiz'|'link'|'video'|'image'|'text'|'countdown'
  t.string :theme
  t.text :description
  t.string :perceived_engagement           # 'high' | 'medium' | 'low'
  t.text :notes
  t.timestamps
  t.index [:competitor_id, :observed_on]
end
```

#### 6. Loop de aprendizado completo

```
ContentSuggestion gerada pelo pipeline
         ↓
OwnPost criado (inspired_by_suggestion preenchido, ou post espontâneo)
         ↓
Transcrição do reel (Transcription::Factory — chaves do usuário via ADR-013)
         ↓
Graph API busca métricas em D+1, D+7, D+30
         ↓
Usuário preenche performance_rating + performance_notes (formulário rápido)
         ↓
UpdatePlaybookStep recebe: "sugeri X, postou Y com ajuste Z, resultado W"
         ↓
Playbook aprende com resultado real — não só teoria de concorrente
```

#### 7. `Insights::ProfileEvolutionStep`

Job semanal por `OwnProfile`. Gera relatório de evolução incorporado como seção "Evolução do Meu Perfil" no playbook vinculado.

**Consequências:**
- ✅ Fecha o loop sugestão → resultado real → aprendizado
- ✅ Métricas privadas reais via Graph API
- ✅ Tom de voz aprendido de transcrições reais
- ✅ Múltiplos perfis próprios por conta, cada um vinculado ao playbook correto
- ⚠️ Token Meta expira em 60 dias — alerta 7 dias antes obrigatório
- ⚠️ `performance_notes` depende de disciplina do usuário — UI deve minimizar fricção

**Status:** ✅ Travada. Implementar na Fase 3.1.

---

### ADR-013: BYOK (Bring Your Own Keys) e Escolha de Provider por Use Case

**Contexto:** Cada usuário traz suas próprias chaves de API. O produto não centraliza nem paga chamadas de IA. Usuários escolhem provider preferido por use case dentro de limites técnicos definidos.

**Decisão:**

#### 1. Model `ApiCredential` por conta

```ruby
create_table :api_credentials do |t|
  t.references :account, null: false, foreign_key: true
  t.string :provider, null: false          # 'openai' | 'anthropic' | 'assemblyai'
  t.string :encrypted_api_key, null: false # via ActiveRecord::Encryption (ADR-006)
  t.boolean :active, default: true
  t.datetime :last_validated_at
  t.integer :last_validation_status, default: 0  # enum: unknown | verified | failed | quota_exceeded
  t.timestamps
  t.index [:account_id, :provider], unique: true
end
```

Validação ao salvar: chamada de teste mínima (1 token) antes de aceitar.

#### 2. Escolha de provider por use case

| Use Case | Opções | Default sugerido | Observação |
|----------|--------|-----------------|------------|
| **Transcrição** | OpenAI ou AssemblyAI | AssemblyAI | Free tier $50 reduz fricção de onboarding |
| **Análise estruturada** (AnalyzeStep) | OpenAI ou Anthropic | OpenAI | gpt-4o-mini mais barato para JSON |
| **Geração de conteúdo** (sugestões + playbook) | OpenAI ou Anthropic | Anthropic | Sonnet/Opus superiores em criatividade |

Configuração em JSONB no `Account`:

```ruby
# account.llm_preferences (JSONB)
{
  "transcription_provider": "assemblyai",   # 'openai' | 'assemblyai'
  "transcription_model": "default",          # modelo default do provider
  "analysis_provider": "openai",
  "analysis_model": "gpt-4o-mini",
  "generation_provider": "anthropic",
  "generation_model": "claude-sonnet-4-6"
}
```

#### 3. Resolução de provider nos Steps

A resolução de provider/model/api_key acontece nos Steps (`AnalyzeStep`, `GenerateSuggestionsStep`, `TranscribeStep`), **não** no `LLM::Gateway`.

**Motivo:** o Gateway é infraestrutura reusável e deve receber `provider:`, `model:` e `api_key:` já resolvidos. Os Steps conhecem seu `use_case` e consultam `account.llm_preferences` e `account.api_credentials` diretamente.

```ruby
# Exemplo em AnalyzeStep (simplificado)
provider = account.llm_preferences.dig("analysis_provider") || "anthropic"
model    = account.llm_preferences.dig("analysis_model")    || "claude-sonnet-4-6"
api_key  = ApiCredential.active.find_by(account: account, provider: provider)
                               &.decrypted_api_key
raise LLM::MissingApiKeyError unless api_key

LLM::Gateway.call(provider: provider, model: model, api_key: api_key,
                  messages: ..., use_case: "reel_analysis")
```

O Gateway usa `use_case` apenas para logging (`LLMUsageLog`), não para roteamento.

#### 4. Sem fallback automático entre providers

Se chave falhou → análise falha com mensagem clara e acionável. Sem fallback silencioso para chave do servidor — não há chave do servidor para LLM.

Isso vale pros 3 use cases (transcrição, análise, geração). Se usuário configurou `transcription_provider: assemblyai` mas não tem credential AssemblyAI ativa, transcrição falha com `ApiCredentials::NotConfiguredError`. Sistema NÃO tenta OpenAI como fallback.

#### 5. Chaves do servidor em produção

`.env.production` **não contém** `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` nem `ASSEMBLYAI_API_KEY`. Apenas:
- `APIFY_API_TOKEN` — scraping é responsabilidade da plataforma
- Chaves de infraestrutura (Postgres, Redis, SMTP, etc)

#### 6. Onboarding de chaves

Antes da primeira análise, sistema verifica via `current_tenant.ready_for_analysis?` se existe:
- Credential ativa de `transcription_provider` configurado
- Credential ativa de `analysis_provider` configurado
- Credential ativa de `generation_provider` configurado

Se faltar qualquer uma, redireciona para Configurações → API Keys com tutorial inline e mensagem específica de qual credential falta.

#### 7. UI de configuração

**Seção "API Keys":** campo + validar + badge de status por provider.

**Seção "Preferências de Provider":**
- Transcrição → seletor OpenAI | AssemblyAI + modelo
- Análise estruturada → seletor OpenAI | Anthropic + modelo
- Geração de conteúdo → seletor OpenAI | Anthropic + modelo

**Consequências:**
- ✅ Custo operacional de IA cai a zero — cada usuário paga suas próprias chamadas
- ✅ Usuário tem controle total sobre provider e custo
- ✅ Sem lock-in de provider
- ✅ Chaves encryptadas no banco
- ⚠️ Onboarding com fricção nova — usuário precisa ter contas com os providers escolhidos (OpenAI, Anthropic e/ou AssemblyAI). Mitigação: tutorial inline detalhado
- ⚠️ Quota esgotada do usuário = análise falha. Mitigação: mensagem de erro com link para dashboard do provider

**Status:** ✅ Travada. Implementar na **Fase 1.6a** — pré-requisito para primeira análise do usuário.

---

## O que NÃO usar

Lista explícita de tecnologias/ferramentas proibidas (ou que exigem ADR específico para aprovar):

- ❌ **React, Vue, Angular, Svelte, qualquer SPA**
- ❌ **jQuery**
- ❌ **Sass/SCSS, Less** (Tailwind puro)
- ❌ **CSS-in-JS**
- ❌ **Webpack, esbuild, Vite como bundler** (importmap padrão)
- ❌ **AWS, Google Cloud, Azure** (VPS Hostinger é a infra)
- ❌ **Kubernetes** (Docker Compose basta)
- ❌ **MongoDB, MySQL, outros bancos** (Postgres + pgvector)
- ❌ **GraphQL** (REST JSON é suficiente)
- ❌ **OAuth providers custom** (Devise padrão)
- ❌ **Elasticsearch** (Postgres full-text search basta no MVP)
- ❌ **ffmpeg** (ADR-008 — upload direto de MP4 pra OpenAI)
- ❌ **OpenAI Assistants API / Vector Store** (ADR-008 — incompatível com neutralidade LLM)
- ❌ **pgvector em uso no MVP** (habilitado mas sem uso até Fase 2.5)
- ❌ **aasm ou gems de state machine** (enum + transições manuais bastam no MVP)
- ❌ **Paralelismo no pipeline de análise** (Parallel gem, threads, múltiplos workers) — serial no MVP
- ❌ **Chaves API de LLM no servidor** (ADR-013 — BYOK obrigatório, cada usuário traz as suas)

---

## Performance e escala (metas MVP)

| Métrica | Meta |
|---------|------|
| Response time mediana (web) | < 300ms |
| Response time p95 (web) | < 800ms |
| Duração média de análise completa | < 4 min |
| Concorrência Sidekiq default | 5 workers |
| Conversões 1 VPS Hostinger 4GB comporta | até ~100 contas ativas |

> **Nota sobre duração da análise:** Com ProfileMetricsStep, ScoreAndSelectStep, TranscribeStep (12 reels), AnalyzeStep (3 chamadas) e UpdatePlaybookStep, duração sobe pra ~4-5min quando playbook está ativo. Aceitável — usuário dispara e recebe email quando pronto (Fase 1.7).

---

## Custo estimado por análise (MVP)

Custo é **do usuário** via BYOK (ADR-013). Estimativa de referência em USD (abril/2026):

| Componente | Custo estimado | Notas |
|------------|----------------|-------|
| Apify scrape (30 posts) | ~$0,03 | Plataforma paga — não é custo do usuário |
| Transcrição (12 reels × ~40s) | ~$0,01 | gpt-4o-mini-transcribe, chave do usuário |
| AnalyzeStep (3 chamadas gpt-4o-mini) | ~$0,01 | Prompt focado, output JSON |
| GenerateSuggestionsStep (Claude Sonnet) | ~$0,02 | Output criativo |
| UpdatePlaybookStep (Claude Sonnet) | ~$0,03 | Por playbook selecionado |
| **Total por análise (1 playbook)** | **~$0,07** | Custo do usuário |

> Custo em BRL depende da taxa de câmbio no momento do uso. Estimativa: ~R$ 0,40/análise com câmbio de R$ 5,70.

---

**Última atualização:** Fase 1.6 T5 — Interface Web concluída. Gems sem pin explícito (versões em Gemfile.lock), assemblyai adicionada. ADR-001: Scraping::Result com `message` (não `error_code`) e `bio` (não `biography`). ADR-006: campo encryptado atual é apenas `ApiCredential#encrypted_api_key`; `OwnProfile#meta_access_token` planejado para Fase 3.1. ADR-013: enum `verified`/`failed` (não `valid`/`invalid`); resolução de provider acontece nos Steps, não no Gateway. ViewComponent marcado como não usado no MVP.
