# 05_GLOSSARIO — Termos, Naming e Schemas

> Referência rápida para nomes, enums, termos de domínio e schemas. Consultar antes de criar qualquer model ou endpoint novo.

---

## Termos de domínio

| Termo | Definição |
|-------|-----------|
| **Account** | Conta de um usuário na plataforma. Unidade de tenant. No MVP, 1 usuário por account. |
| **Competitor** | Perfil Instagram que o usuário quer analisar. |
| **Analysis** | Execução completa (scrape + metrics + score + transcribe + analyze + generate). |
| **Post** | Post individual capturado no scraping. Pertence a uma Analysis. `reel`, `carousel` ou `image`. |
| **ContentSuggestion** | Sugestão gerada pela IA. 5 por Analysis (2 reels + 2 carrosséis + 1 imagem, com fallback). |
| **Handle** | Username Instagram sem `@`, lowercase. |
| **Quality Score** | Score numérico Ruby (sem IA) pra rankear posts dentro de cada tipo. |
| **Selected for Analysis** | Flag no Post marcando se foi escolhido pro LLM. Top N proporcional por tipo. |
| **Profile Metrics** | Métricas agregadas do perfil em Ruby: frequência, mix, horários, hashtags. Em `analyses.profile_metrics` (JSONB). |
| **Transcript** | Transcrição do áudio de um reel. Em `posts.transcript`. |
| **Insights** | Hash JSON da IA com análise segmentada por tipo (reel, carousel, image). |
| **Hook (Gancho)** | Primeira linha impactante de um post. |
| **Scraping Provider** | Abstração do scraping. MVP: Apify. |
| **Transcription Provider** | Abstração de transcrição. Providers: OpenAI ou AssemblyAI. Default: AssemblyAI. |
| **LLM Gateway** | Classe que unifica chamadas a OpenAI/Anthropic. |
| **Use Case** | Contexto de chamada LLM para logging. Valores: `"reel_analysis"`, `"carousel_analysis"`, `"image_analysis"`, `"content_suggestions"`. |
| **max_posts** | Input do usuário por análise: quantos posts o scraper captura (range 10-100, default 50). |

---

## Schemas dos modelos

### Account

```ruby
create_table :accounts do |t|
  t.string :name, null: false
  t.jsonb :llm_preferences, default: {}, null: false
  t.jsonb :media_generation_preferences, default: {}, null: false
  t.timestamps
end
```

> Não há campo `subdomain`. App roda sempre em `viralspy.curt.com.br`.

> **Nota:** `llm_preferences` guarda preferências de provider/modelo por use_case
> (ADR-013). Chaves esperadas (todas strings): `transcription_provider`,
> `transcription_model`, `analysis_provider`, `analysis_model`,
> `generation_provider`, `generation_model`. Valores ausentes caem no default
> via `Account#llm_preferences_with_defaults`.

### ApiCredential

```ruby
create_table :api_credentials do |t|
  t.references :account, null: false, foreign_key: true
  t.string :provider, null: false          # "openai" | "anthropic" | "assemblyai" | "heygen"
  t.string :encrypted_api_key, null: false # encryptada via ActiveRecord::Encryption
  t.boolean :active, default: true, null: false
  t.datetime :last_validated_at
  t.integer :last_validation_status, default: 0, null: false
  t.timestamps
end
add_index :api_credentials, [:account_id, :provider], unique: true
```

> Enum `provider`: string-backed (`openai`, `anthropic`, `assemblyai`, `heygen`), prefix `provider_`.
> Enum `last_validation_status`: integer-backed (`unknown`, `verified`, `failed`, `quota_exceeded`), prefix `validation_`.

### User

```ruby
create_table :users do |t|
  # Devise padrão
  t.string :first_name
  t.string :last_name
  t.references :account, null: false, foreign_key: true
  t.timestamps
end
```

### Competitor

```ruby
create_table :competitors do |t|
  t.references :account, null: false, foreign_key: true
  t.string :instagram_handle, null: false  # sem @, lowercase
  t.string :niche                           # nicho livre-texto, max 120 chars. Usado nos prompts LLM via niche_for_prompt
  t.string :full_name
  t.text :bio
  t.integer :followers_count
  t.integer :following_count
  t.integer :posts_count
  t.string :profile_pic_url
  t.datetime :last_scraped_at
  t.timestamps
  t.index [:account_id, :instagram_handle], unique: true
end
```

### Analysis

```ruby
create_table :analyses do |t|
  t.references :account, null: false, foreign_key: true
  t.references :competitor, null: false, foreign_key: true
  t.integer :status, default: 0, null: false
  t.integer :max_posts, null: false, default: 50
  t.string :scraping_provider    # 'apify'
  t.string :scraping_run_id
  t.jsonb :raw_data, default: {}
  t.jsonb :profile_metrics, default: {}  # Ruby puro
  t.jsonb :insights, default: {}          # LLM, segmentado por tipo
  t.integer :posts_scraped_count, default: 0, null: false
  t.integer :posts_analyzed_count, default: 0, null: false
  t.text :error_message
  t.datetime :started_at
  t.datetime :finished_at
  t.timestamps
  t.index [:account_id, :created_at]
  t.index :status
end
```

**Validações no model:**

```ruby
validates :max_posts, numericality: {
  only_integer: true,
  greater_than_or_equal_to: 10,
  less_than_or_equal_to: 100
}
```

> **Nota:** `profile_metrics` e `insights` são separados por propósito. `profile_metrics` é Ruby, determinístico, barato. `insights` é output do LLM, qualitativo, custa tokens.

> **Nota sobre `profile_metrics["refinement_failed"]`:** quando CritiqueAndRefineStep falha, essa chave é adicionada como `true`. Analysis ainda completa normalmente com sugestões originais preservadas.

### Post

```ruby
create_table :posts do |t|
  t.references :analysis, null: false, foreign_key: true
  t.references :competitor, null: false, foreign_key: true
  t.references :account, null: false, foreign_key: true
  t.string :instagram_post_id, null: false
  t.string :shortcode
  t.integer :post_type, null: false  # reel:0, carousel:1, image:2
  t.text :caption
  t.string :display_url
  t.string :video_url              # só reels
  t.integer :likes_count, default: 0
  t.integer :comments_count, default: 0
  t.integer :video_view_count
  t.string :hashtags, array: true, default: []
  t.string :mentions, array: true, default: []
  t.datetime :posted_at
  # Scoring e seleção
  t.decimal :quality_score, precision: 10, scale: 4
  t.boolean :selected_for_analysis, default: false, null: false
  # Transcrição
  t.text :transcript
  t.integer :transcript_status, default: 0, null: false
  t.datetime :transcribed_at
  t.timestamps
  t.index [:account_id, :posted_at]
  t.index :instagram_post_id
  t.index [:analysis_id, :selected_for_analysis]
  t.index [:analysis_id, :post_type, :quality_score]
end
```

### ContentSuggestion

```ruby
create_table :content_suggestions do |t|
  t.references :analysis, null: false, foreign_key: true
  t.references :account, null: false, foreign_key: true
  t.integer :position, null: false                  # 1..5
  t.integer :content_type, null: false              # reel:0, carousel:1, image:2
  t.string :hook
  t.text :caption_draft
  t.jsonb :format_details, default: {}              # estrutura por tipo
  t.string :suggested_hashtags, array: true, default: []
  t.text :rationale
  t.integer :status, default: 0
  t.timestamps
  t.index [:account_id, :created_at]
  t.index [:analysis_id, :content_type]
end
```

> **`format_details` por tipo:**
> - `reel`: `{ duration_seconds: 30, structure: ["hook", "problem", "solution", "cta"] }`
> - `carousel`: `{ slides: [{ title: "...", body: "..." }, ...] }`
> - `image`: `{ composition_tips: "...", text_overlay: "..." }`

### GeneratedMedia

```ruby
create_table :generated_medias do |t|
  t.references :account, null: false, foreign_key: true
  t.references :content_suggestion, null: false, foreign_key: true
  t.string :provider, default: "heygen", null: false  # enum: "heygen"
  t.integer :media_type, default: 0, null: false       # enum: avatar_video(0)
  t.integer :status, default: 0, null: false            # enum: pending(0), processing(1), completed(2), failed(3)
  t.text :prompt_sent
  t.jsonb :provider_params, default: {}
  t.string :provider_job_id
  t.string :output_url
  t.integer :duration_seconds
  t.integer :cost_cents
  t.text :error_message
  t.datetime :started_at
  t.datetime :finished_at
  t.timestamps
  t.index [:account_id, :created_at]
  t.index :content_suggestion_id
  t.index :provider_job_id
  t.index :status
end
```

### MediaGenerationUsageLog

```ruby
create_table :media_generation_usage_logs do |t|
  t.references :account, null: false, foreign_key: true
  t.references :generated_media, null: false, foreign_key: true
  t.string :provider, null: false
  t.integer :duration_seconds
  t.integer :cost_cents
  t.timestamps
  t.index [:account_id, :created_at]
  t.index :generated_media_id
end
```

### Playbook

```ruby
create_table :playbooks do |t|
  t.references :account, null: false, foreign_key: true
  t.string :name, null: false                       # unique per account_id
  t.string :niche
  t.text :purpose
  t.integer :current_version_number, default: 0, null: false
  t.timestamps
  t.index [:account_id, :name], unique: true
end
```

### PlaybookVersion

```ruby
create_table :playbook_versions do |t|
  t.references :account, null: false, foreign_key: true
  t.references :playbook, null: false, foreign_key: true
  t.integer :version_number, null: false             # unique per playbook_id
  t.text :content, null: false
  t.text :diff_summary
  t.bigint :triggered_by_analysis_id                 # FK → analyses
  t.bigint :incorporated_in_version_id               # FK → playbook_versions
  t.integer :feedbacks_incorporated_count, default: 0, null: false
  t.timestamps
  t.index :account_id
  t.index [:playbook_id, :version_number], unique: true
  t.index :triggered_by_analysis_id
  t.index :incorporated_in_version_id
end
```

### PlaybookFeedback

```ruby
create_table :playbook_feedbacks do |t|
  t.references :account, null: false, foreign_key: true
  t.references :playbook, null: false, foreign_key: true
  t.text :content, null: false
  t.string :source, null: false                      # enum: manual(0), auto(1)
  t.integer :status, default: 0, null: false          # enum: pending(0), incorporated(1), dismissed(2)
  t.bigint :incorporated_in_version_id               # FK → playbook_versions
  t.bigint :related_analysis_id                      # FK → analyses
  t.integer :related_own_post_id
  t.timestamps
  t.index :account_id
  t.index [:playbook_id, :status]
  t.index :incorporated_in_version_id
  t.index :related_analysis_id
end
```

### PlaybookSuggestion

```ruby
create_table :playbook_suggestions do |t|
  t.references :account, null: false, foreign_key: true
  t.references :playbook, null: false, foreign_key: true
  t.string :content_type, null: false                # enum: "reel", "carousel", "image", "story"
  t.string :hook
  t.text :caption_draft
  t.jsonb :format_details, default: {}
  t.string :suggested_hashtags, array: true, default: []
  t.text :rationale
  t.integer :status, default: 0, null: false          # enum: draft(0), saved(1), discarded(2)
  t.timestamps
  t.index [:account_id, :created_at]
  t.index [:playbook_id, :status]
end
```

### AnalysisPlaybook

```ruby
create_table :analysis_playbooks do |t|
  t.references :analysis, null: false, foreign_key: true
  t.references :playbook, null: false, foreign_key: true
  t.integer :update_status, default: 0, null: false  # enum: playbook_update_pending(0), playbook_update_completed(1), playbook_update_failed(2)
  t.timestamps
  t.index [:analysis_id, :playbook_id], unique: true
end
```

### LLMUsageLog

> Constante Ruby: `LLMUsageLog` (acrônimo `LLM` em `config/initializers/inflections.rb`). Tabela: `llm_usage_logs` (snake_case padrão).

```ruby
create_table :llm_usage_logs do |t|
  t.references :account, null: false, foreign_key: true
  t.string :provider, null: false           # 'openai' | 'anthropic'
  t.string :model, null: false              # ex: 'claude-opus-4-7'
  t.string :use_case                        # ex: 'reel_analysis', 'critique_and_refine'
  t.integer :prompt_tokens
  t.integer :completion_tokens
  t.integer :cost_cents                     # centavos de BRL
  t.references :analysis, foreign_key: true
  t.timestamps
  t.index [:account_id, :created_at]
end
```

### TranscriptionUsageLog

```ruby
create_table :transcription_usage_logs do |t|
  t.references :account, null: false, foreign_key: true
  t.references :post, foreign_key: true
  t.references :analysis, foreign_key: true
  t.string :provider, null: false                 # 'openai' | 'assemblyai'
  t.string :model, null: false                    # 'gpt-4o-mini-transcribe' (openai) | modelo do provider
  t.integer :audio_duration_seconds
  t.integer :cost_cents
  t.timestamps
  t.index [:account_id, :created_at]
end
```

> Tabela separada da `LLMUsageLog` porque pricing de transcrição é em minutos de áudio, não em tokens. Ambas armazenam `cost_cents` em centavos de BRL (conversão USD→BRL via constantes em `LLM::Pricing` e `Transcription::Pricing`).

### ApiCredential

```ruby
create_table :api_credentials do |t|
  t.references :account, null: false, foreign_key: true
  t.string :provider, null: false            # 'openai' | 'anthropic' | 'assemblyai' | 'heygen'
  t.string :encrypted_api_key, null: false   # ActiveRecord::Encryption — ADR-006
  t.boolean :active, default: true, null: false
  t.datetime :last_validated_at
  t.integer :last_validation_status, default: 0, null: false  # enum
  t.timestamps
  t.index [:account_id, :provider], unique: true
end
```

> **Nota:** credential é única por (account, provider). Usuário pode ter 1 chave OpenAI, 1 Anthropic e 1 AssemblyAI simultaneamente. Remoção apaga o registro (não soft delete — chave comprometida deve sumir).

---

## Enums

### Analysis#status

```ruby
enum :status, {
  pending: 0,                  # criada, aguardando
  scraping: 1,                 # Apify rodando
  scoring: 2,                  # Ruby puro, muito rápido
  transcribing: 3,             # áudio dos reels selecionados
  analyzing: 4,                # 3 chamadas LLM
  generating_suggestions: 5,   # 1 chamada LLM
  # índice 6 reservado (status `refining` removido do enum na Fase 1.5b)
  completed: 7,                # sucesso
  failed: 8                    # falhou em alguma etapa
}
```

> ⚠️ **Nota sobre o índice 6:** o status `refining` foi inserido na Fase 1.5a e removido na Fase 1.5b. O índice 6 está reservado — não reusar para novos status sem migration de dados (evitar colisão com dados históricos).

### Post#post_type

```ruby
enum :post_type, {
  reel: 0,
  carousel: 1,
  image: 2
}
```

### Post#transcript_status

```ruby
enum :transcript_status, {
  pending: 0,
  completed: 1,
  failed: 2,
  skipped: 3
}
```

> **Nota:** na Fase 1.2 havia valor `not_applicable: 4` que foi removido por redundância — usar `skipped` com contexto implícito (se post não é reel, está skipped).

### ContentSuggestion#status

```ruby
enum :status, {
  draft: 0,
  saved: 1,
  discarded: 2
}
```

### ContentSuggestion#content_type

```ruby
enum :content_type, {
  reel: 0,
  carousel: 1,
  image: 2
}
```

### ApiCredential#provider

```ruby
enum :provider, {
  openai: 'openai',
  anthropic: 'anthropic',
  assemblyai: 'assemblyai',
  heygen: 'heygen'
}, _prefix: true
```

> **Nota:** usando `string` em vez de `integer` pro enum — torna queries manuais mais legíveis e permite adicionar providers futuros sem migration de dados.

### ApiCredential#last_validation_status

```ruby
enum :last_validation_status, {
  unknown: 0,          # ainda não validada
  verified: 1,         # última validação ok
  failed: 2,           # 401 do provider (chave revogada/errada)
  quota_exceeded: 3    # 429 do provider (sem crédito/rate limit)
}, _prefix: :validation
```

> **Nota:** `unknown` é default pra credential recém-criada antes de ser validada. `ValidateService` move pra `verified`, `failed` ou `quota_exceeded`.
>
> **Atenção:** `valid` e `invalid` são proibidos como valores de enum no Rails 7.1 (conflito com `#valid?/#invalid?` de `ActiveRecord::Validations`), mesmo com `_prefix`. Usar `verified`/`failed`.

### GeneratedMedia#status

```ruby
enum :status, {
  pending: 0,
  processing: 1,
  completed: 2,
  failed: 3
}
```

### GeneratedMedia#media_type

```ruby
enum :media_type, {
  avatar_video: 0
}
```

### GeneratedMedia#provider

```ruby
enum :provider, {
  heygen: 'heygen'
}, _prefix: :provider
```

### PlaybookFeedback#status

```ruby
enum :status, {
  pending: 0,
  incorporated: 1,
  dismissed: 2
}, _prefix: :status
```

### PlaybookFeedback#source

```ruby
enum :source, {
  manual: 0,
  auto: 1
}, _prefix: :source
```

### PlaybookSuggestion#status

```ruby
enum :status, {
  draft: 0,
  saved: 1,
  discarded: 2
}
```

### PlaybookSuggestion#content_type

```ruby
enum :content_type, {
  reel: 'reel',
  carousel: 'carousel',
  image: 'image',
  story: 'story'
}
```

> **Nota:** string-backed (ao contrário de `ContentSuggestion#content_type` que é integer-backed).

### AnalysisPlaybook#update_status

```ruby
enum :update_status, {
  playbook_update_pending: 0,
  playbook_update_completed: 1,
  playbook_update_failed: 2
}
```

---

## Lógica de scoring (ADR-009)

**Fórmula do `quality_score`:**

```
score = (engagement / max(followers, 1)) × maturity_boost × 1_000_000

onde:
  engagement     = likes_count + (comments_count × 3)
  days_since     = max((Time.now - posted_at) / 1.day, 0.25)
  maturity       = min(days_since / 7.0, 1.0)
  maturity_boost = 1.0 / max(maturity, 0.1)
```

**Filtros de elegibilidade** (posts abaixo NÃO recebem score):
- `likes_count + comments_count >= 3` *(amendment pós-1.5a: era 10)*
- `posted_at <= 6.hours.ago`

**Seleção proporcional ao `analysis.max_posts`** *(amendment pós-1.5a)*:

```ruby
SELECTION_RATIOS = { reel: 0.40, carousel: 0.17, image: 0.10 }
SELECTION_CAPS   = { reel: 20,   carousel: 8,    image: 5    }

def select_count(post_type, posts_scraped)
  ratio = SELECTION_RATIOS.fetch(post_type)
  cap   = SELECTION_CAPS.fetch(post_type)
  [(posts_scraped * ratio).floor, cap].min
end
```

Top-N por `quality_score DESC` dentro de cada tipo. Se tipo não tem posts suficientes, seleciona o que tem e segue.

---

## Lógica de profile_metrics (ADR-009)

Calculado em Ruby a partir de TODOS os posts scraped (antes da seleção). Exemplo de output:

```json
{
  "posts_per_week": 4.2,
  "content_mix": {
    "reel": 0.70,
    "carousel": 0.20,
    "image": 0.10
  },
  "avg_likes_per_post": 324,
  "avg_comments_per_post": 18,
  "avg_engagement_rate": 0.042,
  "top_hashtags": ["#imoveisbh", "#corretordeimoveis", "#casapropria"],
  "best_posting_days": ["Tuesday", "Thursday", "Saturday"],
  "best_posting_hours": [19, 20, 21],
  "posting_consistency_score": 0.85,
  "period_analyzed_days": 42
}
```

> **Chave opcional:** `refinement_failed: true` é adicionada pelo `CritiqueAndRefineStep` quando esse passo falha. Ausente quando refinement ocorre normalmente.

---

## Lógica de sugestões finais (ADR-010)

**Padrão:** 2 reels + 2 carrosséis + 1 imagem = 5 sugestões.

**Fallback quando falta tipo:**

```ruby
mix = { reel: 2, carousel: 2, image: 1 }
mix.each { |type, count| mix[type] = 0 unless has_enough_analysis_of_type?(type) }
fill_remaining_with_reels_until_total_is_5(mix)
```

Ordem de preferência: reel > carousel > image.

---

## Lógica de refinamento (ADR-011)

Após `GenerateSuggestionsStep`, o `CritiqueAndRefineStep` recebe as 5 ContentSuggestions + insights + profile_metrics, faz 1 chamada Opus 4.7 com prompt adversarial, e atualiza as sugestões existentes (não cria novas).

**Output esperado do LLM (array de 5 objetos):**

```json
{
  "suggestion_position": 1,
  "changes_made": ["o que mudou"],
  "hook": "...",
  "caption_draft": "...",
  "format_details": { ... },
  "suggested_hashtags": ["..."],
  "rationale": "explicação da versão final"
}
```

- `changes_made` vai pra `content_suggestions.refinement_notes`
- Campos de conteúdo substituem os originais
- `rationale` do refinement substitui o original

**Se o step falha:** sugestões originais preservadas, `analysis.profile_metrics["refinement_failed"] = true`, Analysis completa normalmente.

---

## Convenções de naming

### Modelos

- Singular, PascalCase, substantivo concreto
- ✅ `Competitor`, `Analysis`, `ContentSuggestion`
- ❌ `Competitors`, `AnalysisService`, `Content_suggestion`

### Acrônimos em nomes de classe/módulo

Todo acrônimo usado em nome de constante (`LLM`, `AI`, `API`, `CRM`, `CPF`, etc) **deve estar registrado em `config/initializers/inflections.rb`** antes de criar o arquivo correspondente.

Zeitwerk usa inflections pra resolver autoload: `llm_usage_log.rb` → `LLMUsageLog` (correto) vs. `LlmUsageLog` (errado).

Inflections registradas:
- `LLM`
- `AI`

**Regra:** se o nome da constante tem 2+ letras maiúsculas consecutivas que representam sigla, é acrônimo e precisa de inflection.

### Controllers

- Plural do model, em `app/controllers/`
- ✅ `CompetitorsController`, `AnalysesController`
- Namespace API: `Api::V1::CompetitorsController`

### Services

- Organizados por domínio em `app/services/{dominio}/`
- ✅ `Analyses::ScrapeStep`, `Analyses::ProfileMetricsStep`, `Analyses::ScoreAndSelectStep`, `Analyses::TranscribeStep`, `Analyses::AnalyzeStep`, `Analyses::GenerateSuggestionsStep`, `Analyses::UpdatePlaybookStep`
- ✅ `Analyses::PromptRenderer`, `Analyses::Result`
- ✅ `Analyses::Scoring::Formula`, `Analyses::Scoring::Selector`
- ✅ `Scraping::ApifyProvider`, `Scraping::Apify::Client`, `Scraping::Apify::Parser`, `Scraping::Apify::RunPoller`, `Scraping::Factory`, `Scraping::Result`
- ✅ `Transcription::Providers::OpenAI`, `Transcription::Providers::AssemblyAI`, `Transcription::Factory`, `Transcription::UsageLogger`, `Transcription::Pricing`
- ✅ `LLM::Gateway`, `LLM::Providers::OpenAI`, `LLM::Providers::Anthropic`, `LLM::UsageLogger`, `LLM::Response`
- ✅ `MediaGeneration::Start`, `MediaGeneration::Factory`, `MediaGeneration::Providers::Heygen`, `MediaGeneration::ScriptBuilder`, `MediaGeneration::Result`
- ✅ `ApiCredentials::ValidateService`, `ApiCredentials::Result`
- ✅ `Playbooks::GenerateSuggestionsService`
- Método público padrão: `self.call(...)` ou `#call`

### Workers (Sidekiq)

- Em `app/workers/{dominio}/`
- Sufixo `Worker`
- ✅ `Analyses::RunAnalysisWorker` — queue `analyses`, retry 0, executa pipeline de 6 steps
- ✅ `MediaGeneration::PollWorker` — queue `media_generation`, retry 3, polling HeyGen (MAX_ATTEMPTS=60, POLL_INTERVAL=10s)

### ViewComponents

**Decisão MVP:** não usar gem `view_component`. Reuso visual é feito via partials ERB em `app/views/`.

- Partials compartilhadas ficam em `app/views/shared/` ou subdiretório do contexto
- Ex.: `app/views/analyses/shared/_status_badge.html.erb`

### Stimulus controllers

- Arquivo snake_case, termina em `_controller.js`
- `data-controller` em kebab-case
- ✅ `copy_to_clipboard_controller.js` → `data-controller="copy-to-clipboard"`
- ✅ `api_key_form_controller.js` → `data-controller="api-key-form"` (validação inline de chaves)
- ✅ `hello_controller.js` → boilerplate Rails (pode ser removido)

### Rotas

- Plural e RESTful
- ✅ `resources :competitors do resources :analyses end`

### Migrations

- Timestamp + verbo descritivo
- ✅ `20260419161251_add_max_posts_and_refining_status_to_analyses.rb`
- ✅ `20260420123456_create_competitors.rb`

### Testes

- Mesmo caminho, sufixo `_spec.rb`
- ✅ `app/models/competitor.rb` → `spec/models/competitor_spec.rb`
- ✅ `app/services/scraping/apify_provider.rb` → `spec/services/scraping/apify_provider_spec.rb`

---

## ENV vars

Variáveis esperadas (padrão `.env.example`):

| Variável | Descrição | Obrigatório em produção? | Notas |
|----------|-----------|--------------------------|-------|
| `DATABASE_URL` | Conexão Postgres | Sim | — |
| `REDIS_URL` | Conexão Redis principal | Sim | — |
| `SIDEKIQ_REDIS_URL` | Conexão Redis Sidekiq | Sim | Pode ser DB lógico separado do REDIS_URL |
| `RAILS_MASTER_KEY` | Master key Rails credentials | Sim | — |
| `SECRET_KEY_BASE` | Secret do Rails | Sim | — |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | ActiveRecord::Encryption | Sim | ADR-006 |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | ActiveRecord::Encryption | Sim | — |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | ActiveRecord::Encryption | Sim | — |
| `APIFY_API_TOKEN` | Token Apify | Sim | Scraping é responsabilidade da plataforma |
| `VIRALSPY_HOST` | Hostname do app | Sim | MVP: `viralspy.curt.com.br` |
| `SCRAPING_PROVIDER` | `apify` (único no MVP) | Não | Default: `apify` |
| `SCRAPING_POSTS_PER_ANALYSIS` | Fallback de max_posts quando não informado | Não | Default: `30` |
| `OPENAI_API_KEY` | **APENAS DEV/TESTES.** Em produção é BYOK via `ApiCredential` | Não | ADR-013 |
| `ANTHROPIC_API_KEY` | **APENAS DEV/TESTES.** Em produção é BYOK via `ApiCredential` | Não | ADR-013 |
| `ASSEMBLYAI_API_KEY` | **APENAS DEV/TESTES.** Em produção é BYOK via `ApiCredential` | Não | ADR-013 |
| `ENABLE_SIGNUP` | Feature flag de signup público | Não | Default: `true` |
| `BACKUP_S3_ENDPOINT` | Endpoint Cloudflare R2 para backups | Não | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |
| `BACKUP_S3_ACCESS_KEY` | Access key do token R2 | Não | — |
| `BACKUP_S3_SECRET_KEY` | Secret key do token R2 | Não | — |
| `BACKUP_S3_BUCKET` | Nome do bucket de backup | Não | Default: `viralspy-backups` |
| `BACKUP_S3_REGION` | Região R2 (literalmente `auto`) | Não | — |
| `HEYGEN_WEBHOOK_TOKEN` | Token aleatório para autenticar webhooks do HeyGen | Não (recomendado) | URL: `https://viralspy.curt.com.br/webhooks/heygen?token=TOKEN` |

---

## Namespaces reservados

- `/api/v1/*` — API pública (Fase 2.3)
- `/webhooks/*` — Webhooks entrantes (Fase 2+)
- `/admin/*` — Admin panel (sem fase definida)
- `Integrations::*` — Integrações externas (Fifty, Meta, etc)

---

## Nomes oficiais do produto

- **Nome do produto:** ViralSpy v2 (interno)
- **Nome exibido:** "ViralSpy" (provisório)
- **Domínio MVP:** `viralspy.curt.com.br`
- **Domínio futuro:** a definir, migração após validação do MVP
- **Slogan:** TBD

Não criar "ViralSpyPro", "ViralSpy2.0" ou variações.

---

## Formato de datas e números

- **Timezone:** `America/Sao_Paulo`
- **Locale:** `pt-BR`
- **Data em UI:** `DD/MM/YYYY HH:MM` (ex: `20/04/2026 14:35`)
- **Data em API:** ISO 8601 (ex: `2026-04-20T14:35:00-03:00`)
- **Moeda em UI:** `R$ 1.234,56`
- **Número em API:** decimal padrão (`1234.56`)

---

**Última atualização:** 2026-04-21 — Sincronização automática com código real (schema version 2026_04_21_035646). Adicionados: `media_generation_preferences` em Account; schemas de `generated_medias`, `media_generation_usage_logs`, `playbooks`, `playbook_versions`, `playbook_feedbacks`, `playbook_suggestions`, `analysis_playbooks`; enums de `GeneratedMedia`, `PlaybookFeedback`, `PlaybookSuggestion`, `AnalysisPlaybook`; `heygen` ao enum `ApiCredential#provider`; `MediaGeneration::PollWorker` nos workers; serviços `UpdatePlaybookStep`, `PromptRenderer`, `Scoring::Formula/Selector`, classes MediaGeneration/Playbooks; `HEYGEN_WEBHOOK_TOKEN` nas ENV vars. Ver `/tmp/drift_items.md` para itens que requerem atenção.
