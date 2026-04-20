# 03_ROADMAP_FASES — Fases Atômicas de Implementação

> Fases são executadas em ordem. Uma fase = 1-2 commits testáveis. Não pular fases. Não iniciar a próxima antes da anterior estar mergeada.

---

## Status atual

**Fase atual:** Fase 1.6 (Interface Web) — pronta pra iniciar
**Última fase concluída:** Fase 1.6a (BYOK — Bring Your Own Keys) — mergeada em main
**Próxima fase esperada:** Fase 1.6 → Fase 1.7

---

## Fase 0 — Bootstrap do Projeto ✅ CONCLUÍDA

**Duração estimada:** 1-2 dias
**Commits:** 10

### Objetivo

Criar esqueleto Rails, Docker, gems base, banco inicializado.

### Entregas

- Rails 7.1 + Postgres 16 (com `pgcrypto` e `vector`) + Redis + Sidekiq
- Gems base instaladas: Devise, Pundit, acts_as_tenant, ruby-openai, anthropic, neighbor (pgvector), HTTParty, ViewComponent, RSpec, FactoryBot, WebMock, VCR, shoulda-matchers
- Docker Compose dev com 4 serviços (web, worker, db, redis)
- Dockerfile multi-stage
- Rubocop (`rubocop-rails-omakase`) + ERB Lint configurados
- Timezone `America/Sao_Paulo`, locale `pt-BR`
- Encryption configurado
- README, `.env.example`, `.gitignore`

### Critério de aceite — atingido

- `docker compose up` sobe 4 serviços
- `bin/rspec` roda sem erros
- `bin/rubocop` passa
- `bin/erb_lint --lint-all` passa

---

## Fase 1.1 — Autenticação e Multi-tenancy ✅ CONCLUÍDA

**Duração estimada:** 2-3 dias
**Commits:** 8

### Entregas

- Devise instalado com User (first_name, last_name, belongs_to :account)
- Account (`name:string not null`)
- `acts_as_tenant` com `require_tenant = true`
- Signup custom em `Users::RegistrationsController#create` criando Account + User em transação atômica
- Views Devise em Tailwind puro, pt-BR
- Dashboard placeholder (`/dashboard`)
- Pundit `ApplicationPolicy` com defaults false
- 24 examples passando, 0 offenses, 0 erb_lint errors

---

## Fase 1.2 — Models Core ✅ CONCLUÍDA

**Duração real:** 2 dias
**Commits:** 1 (squashed)
**Resultado:** 92 novos specs (24 → 116 total), 0 failures, 0 offenses

### Entregas

- 6 modelos criados com schema conforme `05_GLOSSARIO.md`: `Competitor`, `Analysis`, `Post`, `ContentSuggestion`, `LLMUsageLog`, `TranscriptionUsageLog`
- Todos tenant-scoped via `acts_as_tenant :account`
- Enums, factories com traits, scopes — ver `05_GLOSSARIO.md` para detalhes

---

## Fase 1.3 — ScrapingProvider (Apify) ✅ CONCLUÍDA

**Duração real:** 1 dia
**Commits:** 11
**Resultado:** 57 novos specs (116 → 173 total), cassette VCR commitado

### Entregas

- `Scraping::BaseProvider`, `Scraping::Result`, hierarquia de erros
- `Scraping::ApifyProvider` com 2 actors em sequência (profile + posts)
- Execução async com polling, timeout 240s
- VCR cassette de `@curtbercht` commitado e sanitizado

---

## Fase 1.4 — LLM Gateway e Transcription Provider ✅ CONCLUÍDA

**Duração real:** ~4 dias
**Commits:** 7+
**Resultado:** 103 novos specs (173 → 276 total)

### Entregas

- `LLM::Gateway`, `LLM::Response`, providers OpenAI e Anthropic
- `LLM::Pricing`, `LLM::UsageLogger`
- `Transcription::Factory`, `Transcription::Providers::OpenAI`
- `Transcription::Pricing`, `Transcription::UsageLogger`

---

## Fase 1.5a — Pipeline: Steps Ruby (Scrape + ProfileMetrics + ScoreAndSelect) ✅ CONCLUÍDA

**Duração real:** ~2 dias
**Commits:** 6
**Resultado:** 73 novos specs (276 → 349 total)

### Entregas

- `Analyses::Result`, `Analyses::ScrapeStep`
- `Analyses::ProfileMetricsStep`, `Analyses::Scoring::Formula`
- `Analyses::ScoreAndSelectStep`
- Top 12 reels + 5 carrosséis + 3 imagens selecionados

---

## Fase 1.5b — Pipeline LLM Completo + Preparação BYOK ✅ CONCLUÍDA

**Duração real:** [preencher com a data real quando você fizer esse update]
**Commits:** ~17 (Tarefa 1 revertida + Tarefa 2 com 7 commits + Tarefa 3 com 4 commits + rollback + diagnósticos)
**Resultado:** 526 specs verdes, 0 failures, pipeline end-to-end funcional

### Entregas

- `Analyses::TranscribeStep` — transcreve reels selecionados, rescue por post (falha individual não derruba pipeline), skip automático de não-reels e file_too_large
- `Analyses::AnalyzeStep` — 3 chamadas LLM independentes por tipo (reels, carousels, images), falha em 1 tipo não derruba os outros, insights salvos em `analysis.insights`
- `Analyses::GenerateSuggestionsStep` — 1 chamada LLM gerando 5 ContentSuggestion com mix default 2+2+1 e fallback dinâmico quando falta insight de algum tipo
- `Analyses::RunAnalysisWorker` — orquestrador Sidekiq (queue: analyses, retry: 0), ActsAsTenant.with_tenant, dono do ciclo de vida (started_at/finished_at)
- `LLM::Gateway` refatorado — api_key agora é kwarg obrigatório, sem leitura de ENV (prep BYOK)
- `Transcription::Factory` refatorado idem
- `LLM::Pricing` atualizado com Claude Sonnet/Opus/Haiku 4.x + warning log pra modelos desconhecidos
- Steps com métodos privados `provider_for`, `model_for`, `api_key_for` — ponto único de troca pra 1.6a
- Cada step seta seu próprio status de entrada (acoplamento eliminado)
- Enum `Analysis#status` limpo — `refining` removido, índice 6 reservado com comentário
- Integration spec end-to-end (9 examples, todas verdes com mocks de scraping/transcription/LLM)

### Decisões arquiteturais tomadas durante a fase

1. **Prompts LLM permanecem em ERB no disco** (`app/prompts/*.erb` via `Analyses::PromptRenderer`). Tentativa de migrar pra `PromptTemplate` em banco foi revertida por incompatibilidade de locals entre os dois sistemas. Débito técnico documentado: quando UI de edição de prompts entrar no roadmap (estimado Fase 2+), migração custa ~1 dia.

2. **Steps carregam a decisão de provider/model/api_key** via métodos privados (`provider_for`, `model_for`, `api_key_for`). Hoje retornam hardcoded/ENV; na Fase 1.6a passam a consultar `account.llm_preferences` e `account.api_credentials`. Opção escolhida deliberadamente sobre centralizar no Gateway — steps são o único ponto com contexto do `account` e `use_case` simultaneamente.

3. **Buraco de enum no índice 6** (ex-`refining`) preservado intencionalmente. Renumerar exigiria migration de dados com risco desnecessário. Comentário no model alerta futuros devs a não reusar o índice.

4. **Duplicação de `provider_for`/`model_for`/`api_key_for` entre AnalyzeStep e GenerateSuggestionsStep** é intencional. Na Fase 1.6a vira concern `Analyses::Concerns::LLMConfigResolver`. Refactor prematuro seria pior que duplicação deliberada nessa fase.

---

## Fase 1.6a — BYOK: API Keys e Preferências de Provider ✅ CONCLUÍDA

**Duração real:** ~5-7 dias (T0-T7 em ~10 commits ao todo)
**Resultado:** 626+ specs verdes, BYOK funcional end-to-end, UI de API Keys em `/settings/api_keys`

### Entregas

- T0: Atualização de docs (ADR-008, ADR-013, 05_GLOSSARIO, 00_NORTE, 03_ROADMAP)
- T1: Model `ApiCredential` + `llm_preferences` (JSONB) no Account, `Account#llm_preferences_with_defaults`, `Account#api_credential_for`
- T2: `ApiCredentials::ValidateService` síncrono com tratamento de 401/429/timeout por provider
- T3: Steps do pipeline (`AnalyzeStep`, `GenerateSuggestionsStep`, `TranscribeStep`) passam a resolver provider/chave via `account`, zero leitura de ENV
- T4: `Account#ready_for_analysis?` + `Account#missing_credentials_for_analysis` + concern `RequiresApiCredentials` (dormente)
- T5a: Design system (tokens Tailwind v4, Inter, layout três-superfícies, página `/design-system` dev-only)
- T5b: UI de API Keys (`Settings::ApiKeysController`, 3 cards por provider, validação síncrona, Stimulus `api_key_form`, `ApiCredentialPolicy`)
- T7: Limpeza de ENVs deprecated + rake task `viralspy:dev_setup_credentials`

### Descobertas técnicas importantes

- Rails 7.1 bloqueia nomes `valid/invalid` em enum mesmo com `_prefix:` (conflito com `#valid?/#invalid?` de `ActiveRecord::Validations`). Enum real de `ApiCredential#last_validation_status`: `unknown/verified/failed/quota_exceeded`.
- Projeto usa `tailwindcss-rails` v4 (Tailwind v4), não v3 — config vai no bloco `@theme {}` no CSS (`app/assets/tailwind/application.css`), não em `tailwind.config.js`.
- Steps do pipeline carregam provider/model/api_key via métodos privados `provider_for`, `model_for`, `api_key_for` — duplicação entre `AnalyzeStep` e `GenerateSuggestionsStep` é intencional; refactor pra concern só quando aparecer terceiro consumidor.
- Anthropic gem retorna objetos Ruby com métodos, não Hash — mocks em specs precisam usar `instance_double`.
- `shoulda-matchers` não funciona em models com `acts_as_tenant` + `require_tenant = true` — escrever validações explícitas envolvendo em `ActsAsTenant.with_tenant(account) do ... end`.

---

## Fase 1.6 — Interface Web

**Duração estimada:** 5-7 dias
**Commits:** 2-3

### Objetivo

UI completa para criar competitor, disparar análise, ver progresso e resultado.

### Escopo

**Controllers:**
- `CompetitorsController` (index, new, create, show, destroy)
- `AnalysesController` (create, show) — seleção de Playbooks ao criar
- `ContentSuggestionsController` (update — save/discard)

**Views principais:**
- Competitors index + competitor show
- Analysis new: input de handle + seleção de playbooks que receberão a análise
- Analysis show: status em tempo real, profile metrics, top posts rankeados, 5 sugestões

**Components:**
- `StatusBadgeComponent`, `SuggestionCardComponent`
- `ProfileMetricsComponent`, `PostRankingComponent`, `ProgressStepsComponent`

**Stimulus controllers:**
- `analysis_status_controller`, `copy_to_clipboard_controller`
- `confirm_controller`, `tab_controller`

### Critério de aceite

- Fluxo end-to-end: cadastro → configurar chaves → criar competitor → rodar análise → ver resultado
- Seleção de playbooks ao disparar análise funcional
- Sugestões com save/discard funcionais
- Zero CSS custom, zero classes criadas, zero CSS inline
- System spec crítico verde

---

## Fase 1.7 — Polimento MVP

**Duração estimada:** 4-6 dias

### Escopo

- Rate limiting de análises
- Email de notificação quando análise completa
- Onboarding da primeira conta
- Empty states e error states
- Responsividade mobile
- Deploy em staging no VPS
- Landing page pública

### Critério de aceite

- App rodando em staging real
- 3-5 análises reais com handles reais
- Qualidade das sugestões validada manualmente
- Emails chegando
- Error handling claro para o usuário

---

## FIM DO MVP (Fase 1 completa)

Após Fase 1.7, produto pronto para **beta fechado com 5-10 usuários convidados**.

Coleta de feedback por 4-6 semanas antes de abrir para qualquer pagante.

---

## Fases 2+ (planejamento revisado pós-ADRs 011-012-013)

Essas fases dependem de validação do MVP. **Não devem ser iniciadas sem confirmação do Curt.**

---

### Fase 2.1 — Playbooks: Base de Conhecimento Viva (ADR-011)

**Depende de:** MVP validado com beta, mínimo 20-30 análises no banco para o playbook ter material relevante.

#### Escopo

- Models: `Playbook`, `PlaybookVersion`, `PlaybookFeedback`, `AnalysisPlaybook`
- `Analyses::UpdatePlaybookStep` — roda ao final do pipeline para cada playbook selecionado
- UI de Playbooks: criar, editar, ver versões, histórico de diff
- UI de Feedbacks: registrar feedback manual, feedback do Claude Project
- Botão "Exportar Playbook" — gera markdown pronto para upload no Claude Project
- Seleção de playbooks ao disparar análise (já prevista na Fase 1.6)

#### Critério de aceite

- Análise completa → `UpdatePlaybookStep` roda → nova `PlaybookVersion` gerada
- Usuário registra feedback → próxima atualização incorpora → `diff_summary` menciona
- Exportar Playbook gera markdown válido e legível
- Histórico de versões navegável na UI

---

### Fase 2.2 — Billing com Stripe

- Integração Stripe (conta separada do Fifty)
- Tabela de planos (Starter / Pro / Agência)
- Webhook handlers
- Portal do cliente
- Limites por plano: número de análises, número de playbooks, acesso a OwnProfile

---

### Fase 2.3 — Monitoramento Automático

- Agendamento recorrente de análises (semanal/quinzenal por competitor)
- Notificação de novos posts virais do concorrente
- Diff entre análises (tema X cresceu Y%)

---

### Fase 2.4 — Integração API com Fifty

- `ApiToken` ativo (escopo, rate limit)
- `/api/v1/competitors`, `/api/v1/analyses`, `/api/v1/content_suggestions` (read-only)
- Webhooks saídos (Analysis completed → Fifty)
- Documentação da API

---

### Fase 2.5 — Embeddings e Busca Semântica

- Usar pgvector (habilitado desde Fase 0) para indexar posts + transcripts + sugestões + playbook
- Buscar "sugestões similares a X" dentro do playbook
- Agrupar temas automaticamente entre análises
- Base para busca contextual no agente

---

### Fase 3.1 — Perfil Próprio: OwnProfile + Meta Graph API (ADR-012)

**Depende de:** Fase 2.1 (Playbooks) estar funcionando — o loop de resultado precisa de um playbook pra alimentar.

#### Escopo

- Models: `OwnProfile`, `OwnPost`, `StoryObservation`
- Integração Meta Graph API: configuração de token, fetch de posts, fetch de métricas
- `OwnPosts::FetchMetricsWorker` — job em D+1, D+7, D+30 após `posted_at`
- Transcrição dos próprios reels via `Transcription::Factory`
- UI: cadastro de OwnProfile + configuração de token Meta
- UI: registro de OwnPost (manual + importação via Graph API)
- UI: formulário rápido de `performance_rating` + `performance_notes`
- UI: formulário de `StoryObservation` — registro manual de stories de concorrentes
- Alerta de token Meta expirando (7 dias antes)

#### Critério de aceite

- Usuário configura OwnProfile com token Meta → sistema valida e exibe posts recentes
- Métricas privadas (alcance, saves, plays) visíveis por post
- OwnPost vinculado a ContentSuggestion que o inspirou
- Transcrição do próprio reel funcional
- performance_rating registrado → aparece no próximo UpdatePlaybookStep
- StoryObservation registrada → aparece no próximo UpdatePlaybookStep

---

### Fase 3.2 — Dashboard de Evolução do Perfil

- `Insights::ProfileEvolutionStep` — job semanal por OwnProfile
- Dashboard visual: frequência de postagem, mix de tipos, engagement médio ao longo do tempo
- Comparação sugestão gerada vs resultado real
- Seção "Evolução do Meu Perfil" incorporada automaticamente no Playbook vinculado
- Correlações: tipo de gancho × resultado, horário × alcance, frequência × crescimento

---

### Fase 4+ — Agendamento de Publicação

- Integração com Meta Graph API (publicação direta)
- Agendamento de posts via ViralSpy
- Calendário de conteúdo

---

### Fase 5+ — Geração de Imagens

- DALL-E 3 ou similar
- Templates imobiliários
- Composição automática (foto do imóvel + texto sugerido)

---

### Fase N — Scraper próprio com proxies residenciais

- Remover dependência de Apify
- Proxies residenciais rotativos
- Anti-bot evasion
- Só vale com escala suficiente para justificar complexidade

---

## Quando criar uma Fase nova

Se o Curt sugerir feature que:
- **Não está no roadmap** → avaliar se cabe em fase existente ou vira nova fase numerada
- **Contradiz NORTE ou ARQUITETURA** → pushback antes de virar spec
- **É muito grande (>2 semanas)** → quebrar em sub-fases atômicas
- **Depende de fase ainda não concluída** → bloquear até dependência estar mergeada

---

**Última atualização:** pós-ADRs 011-012-013. Fase 1.6a adicionada (BYOK antes da UI principal). Fases 2+ reorganizadas: Billing virou 2.2, Playbooks virou 2.1 (prioridade maior). Fase 3.1 (OwnProfile + Meta Graph API) e Fase 3.2 (dashboard de evolução) adicionadas. Não-objetivo "Analytics do próprio perfil" removido do NORTE — agora é objetivo, mas nas fases corretas.
