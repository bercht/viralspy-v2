# 03_ROADMAP_FASES — Fases Atômicas de Implementação

> Fases são executadas em ordem. Uma fase = 1-2 commits testáveis. Não pular fases. Não iniciar a próxima antes da anterior estar mergeada.

---

## Status atual

**Fase atual:** Fase 2.0 (Fix Anthropic) — pré-requisito, em andamento
**Última fase concluída:** Fase 1.6 (Interface Web) — mergeada em main
**Próxima fase esperada:** Fase 2.0 → 2.1 → 2.2 → 2.3 → 2.4

**Contexto:** MVP funcional (signup → BYOK → competitor → análise → sugestões). 658 specs verdes. Fase 1.7 (polimento MVP original) e todo roadmap pós-MVP foi repriorizado para uso pessoal + 4-5 convidados. Sem beta pago, sem Stripe, sem landing pública no horizonte curto.

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

## Fase 1.6a — BYOK: API Keys e Preferências de Provider ⚠️ NOVA

**Duração estimada:** 2-3 dias
**Commits:** 2

### Objetivo

Implementar o sistema de chaves próprias do usuário (ADR-013) antes de qualquer UI de análise. Pré-requisito para o usuário conseguir rodar sua primeira análise.

### Escopo

- Model `ApiCredential` com `encrypts :encrypted_api_key`
- JSONB `llm_preferences` no `Account`
- `ApiCredentials::ValidateService` — chamada de teste mínima ao provider
- Atualizar `LLM::Gateway` para resolver provider/chave via `account` (não ENV)
- Atualizar `Transcription::Factory` idem
- Controller + views de configuração: tela "API Keys" + tela "Preferências de Provider"
- Onboarding gate: antes da primeira análise, verifica chaves e redireciona se não configuradas
- Tutorial inline com links para geração de chaves em cada provider

### Critério de aceite

- Usuário sem chaves configuradas não consegue iniciar análise — é redirecionado com mensagem clara
- Usuário configura chave OpenAI → sistema valida → badge "válida" aparece
- Usuário configura chave Anthropic → sistema valida → badge "válida" aparece
- Chave inválida → badge "inválida" com mensagem específica
- Quota esgotada → badge "quota esgotada" com link para dashboard do provider
- Pipeline de análise usa chaves do usuário, não ENV

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

**Fase atual:** Fase 2.0 (Fix Anthropic) — pré-requisito, em andamento
**Última fase concluída:** Fase 1.6 (Interface Web) — mergeada em main
**Próxima fase esperada:** Fase 2.0 → 2.1 → 2.2 → 2.3 → 2.4

**Contexto:** MVP funcional (signup → BYOK → competitor → análise → sugestões). 658 specs verdes. Fase 1.7 (polimento MVP original) e todo roadmap pós-MVP foi repriorizado para uso pessoal + 4-5 convidados. Sem beta pago, sem Stripe, sem landing pública no horizonte curto.



Se o Curt sugerir feature que:
- **Não está no roadmap** → avaliar se cabe em fase existente ou vira nova fase numerada
- **Contradiz NORTE ou ARQUITETURA** → pushback antes de virar spec
- **É muito grande (>2 semanas)** → quebrar em sub-fases atômicas
- **Depende de fase ainda não concluída** → bloquear até dependência estar mergeada

---

**Última atualização:** pós-Fase 1.6 mergeada. Roadmap pós-MVP completamente redesenhado para uso pessoal + 4-5 convidados (sem beta pago, sem Stripe, sem landing). Nova sequência: 2.0 Fix Anthropic → 2.1 Playbook integral → 2.2 MediaGen HeyGen enxuto → 2.3 OwnProfile + Meta Graph → 2.4 Loop Completo. Fases antigas 2.2-2.5 e todo o 06_ROADMAP_PERFORMANCE.md arquivados como referência — ver "Fases futuras" no fim do arquivo.
