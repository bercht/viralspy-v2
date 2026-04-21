# Auditoria — /docs/ vs repo real
Data: 20/04/2026
Commit HEAD: 17df698e8dbe62d088083ab34bb37ae61976b91f

## Resumo executivo
- Total de divergências encontradas: 26
- Críticas (afetam geração de prompts futuros): 24
- Menores (cosméticas/processo): 2

## Estado real capturado

### `git log --oneline -50`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
17df698 feat(fase-1.6): visualização rica do resultado da análise (T4)
71992f6 fix(analyses): show current status in _in_progress heading + remove orphaned refresh_hint locale key
f6a1363 feat(analyses): wire turbo_stream_from + remove meta refresh
c8c9ebe fix(analyses): use tag.li instead of tag.div in _list_item to maintain valid ul>li structure
fc8f0e4 feat(analyses): add _analysis_body and _list_item partials with dom_id wrappers
8cfe46d fix(analyses): revert dom_id to ActionView::RecordIdentifier.dom_id (not available as instance method)
bc2b824 style(analyses): use dom_id helper directly in broadcast_status_change
20a6eb4 feat(analyses): broadcast status changes via Turbo Stream
f7eb418 fix(analyses): include AnalysesHelper in controller + add helper spec
2eee06f chore(specs): remove unnecessary action_cable/testing/rspec require (rspec-rails 6 includes it)
e2f1194 refactor(analyses): completed_locals helper + convert _completed to locals
66b5680 chore(cable): switch dev adapter to Redis + add action_cable testing require
ec875fa docs: T3 implementation plan — Turbo Stream + ActionCable
863d5f4 docs: T3 design spec — Turbo Stream + ActionCable real-time broadcasts
c6a46b9 feat(analyses): new analysis UI + show states + 10s meta refresh
ee6e67d feat(analyses): new/create with max_posts + activate credentials gate
733ad47 refactor(views): migrate dashboard + competitors to design system tokens
0ad213c chore(byok): remove deprecated LLM envs + add dev_setup_credentials rake task
3ccb675 feat(settings): UI for API Keys page
38d463b feat(settings): add Settings::ApiKeysController + routes + policy
896eb78 fix(design-system): migrate tokens from tailwind.config.js to @theme (v4)
0c6eae6 Merge feat/fase-1.6a-t5a-design-system into main
fd8bbf4 feat(design-system): establish visual tokens and three-surface layout
d43b28b feat(1.6a): add ready_for_analysis? gate and RequiresApiCredentials concern
cba8588 test(fase-1.6a): migrate step specs from ENV to ApiCredential fixtures
20a48d0 feat(fase-1.6a): steps resolve provider/model/api_key via account
ef2167c refactor(transcription): require provider: kwarg in Factory, remove ENV defaults
51b698c refactor(fase-1.6a): use typed Faraday rescues in validate_assemblyai; minor spec improvements
bdb051d test(fase-1.6a): fix SQL interpolation and strengthen assertion in api_credentials specs
3b91135 test(fase-1.6a): specs for ApiCredentials::ValidateService, Result, and error hierarchy
f7ece7a fix(fase-1.6a): protect persist_status in outer rescue and remove unnecessary .to_s
acc8d7f feat(fase-1.6a): ApiCredentials error hierarchy, Result, and ValidateService skeleton
284e28c chore: add .worktrees/ to gitignore
d78bc78 docs(fase-1.6a): add llm_preferences and ApiCredential schema to glossary
734ca96 feat(fase-1.6a): ApiCredential model + Account BYOK helpers
569a805 feat(fase-1.6a): add api_credentials table and llm_preferences to accounts
2947395 chore(analyses): remove orphan refining status from enum
e6679c4 refactor(analyses): each step owns its own entry status (no cross-step coupling)
ee09d5f feat(analyses): TranscribeStep sets :transcribing status on entry
0e382d4 refactor(analyses): worker owns started_at lifecycle, not ScrapeStep
73cf2b0 test(integration): update worker spec stubs to match new api_key signatures
09d4fcb chore(llm): add pricing for Claude 4.x models and warning for unknown models
3b79ee2 refactor(transcription): factory and providers require explicit api_key
9bb6c43 refactor(llm): remove transitory ENV fallback, api_key now mandatory
5b32a61 refactor(analyses): extract provider/model/api_key resolution into private methods
8c1ae12 refactor(llm): gateway accepts explicit api_key, falls back to ENV for migration
9f55ac0 refactor(llm): require explicit api_key in provider initializers
8b410e8 revert(fase-1.5b): remove PromptTemplate, keep PromptRenderer as source of truth
6fe12bb feat(fase-1.5b): add PromptTemplate model with seeded v1 prompts
670db79 fix(llm): sanitizar markdown fence antes de parsear JSON
```

### `ls app/models/`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
account.rb
analysis.rb
api_credential.rb
application_record.rb
competitor.rb
concerns
content_suggestion.rb
llm_usage_log.rb
post.rb
transcription_usage_log.rb
user.rb
```

### `ls db/migrate/ | sort`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
20260418193147_enable_extensions.rb
20260418195624_create_accounts.rb
20260418200015_devise_create_users.rb
20260418211505_create_competitors.rb
20260418211730_create_analyses.rb
20260418211855_create_posts.rb
20260418212017_create_content_suggestions.rb
20260418212320_create_llm_usage_logs.rb
20260418212421_create_transcription_usage_logs.rb
20260419161251_add_max_posts_and_refining_status_to_analyses.rb
20260420040804_add_llm_preferences_to_accounts.rb
20260420040818_create_api_credentials.rb
```

### `find app/services -name "*.rb" | sort`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
app/services/analyses/analyze_step.rb
app/services/analyses/generate_suggestions_step.rb
app/services/analyses/profile_metrics_step.rb
app/services/analyses/prompt_renderer.rb
app/services/analyses/result.rb
app/services/analyses/score_and_select_step.rb
app/services/analyses/scoring/formula.rb
app/services/analyses/scoring/selector.rb
app/services/analyses/scrape_step.rb
app/services/analyses/transcribe_step.rb
app/services/api_credentials.rb
app/services/api_credentials/result.rb
app/services/api_credentials/validate_service.rb
app/services/llm/authentication_error.rb
app/services/llm/error.rb
app/services/llm/gateway.rb
app/services/llm/invalid_request_error.rb
app/services/llm/missing_api_key_error.rb
app/services/llm/model_not_found_error.rb
app/services/llm/pricing.rb
app/services/llm/provider_not_found_error.rb
app/services/llm/providers/anthropic.rb
app/services/llm/providers/base.rb
app/services/llm/providers/open_ai.rb
app/services/llm/rate_limit_error.rb
app/services/llm/response.rb
app/services/llm/response_parse_error.rb
app/services/llm/timeout_error.rb
app/services/llm/usage_logger.rb
app/services/scraping/apify/client.rb
app/services/scraping/apify/parser.rb
app/services/scraping/apify/run_poller.rb
app/services/scraping/apify_provider.rb
app/services/scraping/base_provider.rb
app/services/scraping/empty_dataset_error.rb
app/services/scraping/error.rb
app/services/scraping/factory.rb
app/services/scraping/parse_error.rb
app/services/scraping/profile_not_found_error.rb
app/services/scraping/rate_limit_error.rb
app/services/scraping/result.rb
app/services/scraping/run_failed_error.rb
app/services/scraping/timeout_error.rb
app/services/transcription/authentication_error.rb
app/services/transcription/base_provider.rb
app/services/transcription/download_error.rb
app/services/transcription/error.rb
app/services/transcription/factory.rb
app/services/transcription/file_too_large_error.rb
app/services/transcription/missing_api_key_error.rb
app/services/transcription/pricing.rb
app/services/transcription/provider_not_found_error.rb
app/services/transcription/providers/assembly_ai.rb
app/services/transcription/providers/open_ai.rb
app/services/transcription/rate_limit_error.rb
app/services/transcription/response_parse_error.rb
app/services/transcription/result.rb
app/services/transcription/timeout_error.rb
app/services/transcription/usage_logger.rb
```

### `find app/workers -name "*.rb" | sort`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
app/workers/analyses/run_analysis_worker.rb
```

### `find app/controllers -name "*.rb" | sort`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
app/controllers/analyses_controller.rb
app/controllers/application_controller.rb
app/controllers/competitors_controller.rb
app/controllers/concerns/requires_api_credentials.rb
app/controllers/content_suggestions_controller.rb
app/controllers/dashboard_controller.rb
app/controllers/design_system_controller.rb
app/controllers/settings/api_keys_controller.rb
app/controllers/users/confirmations_controller.rb
app/controllers/users/omniauth_callbacks_controller.rb
app/controllers/users/passwords_controller.rb
app/controllers/users/registrations_controller.rb
app/controllers/users/sessions_controller.rb
app/controllers/users/unlocks_controller.rb
```

### `ls app/javascript/controllers/`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
api_key_form_controller.js
application.js
copy_to_clipboard_controller.js
hello_controller.js
index.js
```

### `cat db/schema.rb | grep -E "^\s*create_table|^\s*t\." | head -200`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "llm_preferences", default: {}, null: false
  create_table "analyses", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "competitor_id", null: false
    t.integer "status", default: 0, null: false
    t.string "scraping_provider"
    t.string "scraping_run_id"
    t.jsonb "raw_data", default: {}, null: false
    t.jsonb "profile_metrics", default: {}, null: false
    t.jsonb "insights", default: {}, null: false
    t.integer "posts_scraped_count", default: 0, null: false
    t.integer "posts_analyzed_count", default: 0, null: false
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_posts", default: 50, null: false
    t.index ["account_id", "created_at"], name: "index_analyses_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_analyses_on_account_id"
    t.index ["competitor_id"], name: "index_analyses_on_competitor_id"
    t.index ["status"], name: "index_analyses_on_status"
  create_table "api_credentials", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "provider", null: false
    t.string "encrypted_api_key", null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_validated_at"
    t.integer "last_validation_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider"], name: "index_api_credentials_on_account_id_and_provider", unique: true
    t.index ["account_id"], name: "index_api_credentials_on_account_id"
  create_table "competitors", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "instagram_handle", null: false
    t.string "full_name"
    t.text "bio"
    t.integer "followers_count"
    t.integer "following_count"
    t.integer "posts_count"
    t.string "profile_pic_url"
    t.datetime "last_scraped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "instagram_handle"], name: "index_competitors_on_account_id_and_instagram_handle", unique: true
    t.index ["account_id"], name: "index_competitors_on_account_id"
  create_table "content_suggestions", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "account_id", null: false
    t.integer "position", null: false
    t.integer "content_type", null: false
    t.string "hook"
    t.text "caption_draft"
    t.jsonb "format_details", default: {}, null: false
    t.string "suggested_hashtags", default: [], null: false, array: true
    t.text "rationale"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_content_suggestions_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_content_suggestions_on_account_id"
    t.index ["analysis_id", "content_type"], name: "index_content_suggestions_on_analysis_id_and_content_type"
    t.index ["analysis_id", "position"], name: "index_content_suggestions_on_analysis_id_and_position", unique: true
    t.index ["analysis_id"], name: "index_content_suggestions_on_analysis_id"
  create_table "llm_usage_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "analysis_id"
    t.string "provider", null: false
    t.string "model", null: false
    t.string "use_case"
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_llm_usage_logs_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_llm_usage_logs_on_account_id"
    t.index ["analysis_id"], name: "index_llm_usage_logs_on_analysis_id"
  create_table "posts", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "competitor_id", null: false
    t.bigint "account_id", null: false
    t.string "instagram_post_id", null: false
    t.string "shortcode"
    t.integer "post_type", null: false
    t.text "caption"
    t.string "display_url"
    t.string "video_url"
    t.integer "likes_count", default: 0, null: false
    t.integer "comments_count", default: 0, null: false
    t.integer "video_view_count"
    t.string "hashtags", default: [], null: false, array: true
    t.string "mentions", default: [], null: false, array: true
    t.datetime "posted_at"
    t.decimal "quality_score", precision: 10, scale: 4
    t.boolean "selected_for_analysis", default: false, null: false
    t.text "transcript"
    t.integer "transcript_status", default: 0, null: false
    t.datetime "transcribed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "posted_at"], name: "index_posts_on_account_id_and_posted_at"
    t.index ["account_id"], name: "index_posts_on_account_id"
    t.index ["analysis_id", "post_type", "quality_score"], name: "index_posts_on_analysis_id_and_post_type_and_quality_score"
    t.index ["analysis_id", "selected_for_analysis"], name: "index_posts_on_analysis_id_and_selected_for_analysis"
    t.index ["analysis_id"], name: "index_posts_on_analysis_id"
    t.index ["competitor_id"], name: "index_posts_on_competitor_id"
    t.index ["instagram_post_id"], name: "index_posts_on_instagram_post_id"
  create_table "transcription_usage_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "post_id"
    t.bigint "analysis_id"
    t.string "provider", null: false
    t.string "model", null: false
    t.integer "audio_duration_seconds"
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_transcription_usage_logs_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_transcription_usage_logs_on_account_id"
    t.index ["analysis_id"], name: "index_transcription_usage_logs_on_analysis_id"
    t.index ["post_id"], name: "index_transcription_usage_logs_on_post_id"
  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
```

### `bin/rspec --format progress 2>&1 | tail -20`
```bash
/Users/curt/.rvm/scripts/rvm:29: operation not permitted: ps
zsh:1: no such file or directory: bin/rspec
```

### Observação adicional sobre a suíte
- Tentativas de fallback para `bundle exec rspec` (host) e execução no container falharam por ambiente/permissão, então não foi possível confirmar numericamente o total de exemplos/falhas nesta auditoria.

## Divergências por arquivo

### docs/03_ROADMAP_FASES.md

#### Divergência 1: status do topo está desatualizado 🚨
- **Seção afetada:** `Status atual`
- **Doc diz:** "**Fase atual:** Fase 1.6 (Interface Web) — pronta pra iniciar"
- **O que o código tem:** commits recentes de Fase 1.6 já concluídos até T4 (`17df698`, `f6a1363`, `c6a46b9`, `ee6e67d`) e UI de análise em produção local.
- **Tipo:** (b) fase não marcada como concluída
- **Patch proposto:**
```diff
- **Fase atual:** Fase 1.6 (Interface Web) — pronta pra iniciar
- **Última fase concluída:** Fase 1.6a (BYOK — Bring Your Own Keys) — mergeada em main
- **Próxima fase esperada:** Fase 1.6 → Fase 1.7
+ **Fase atual:** Fase 1.6 (Interface Web) — T1/T2/T3/T4 concluídas
+ **Última fase concluída:** Fase 1.6 (T4) — mergeada em main
+ **Próxima fase esperada:** Fase 1.6 T4.5 (estabilização da suíte) → T5
```

#### Divergência 2: seção da Fase 1.6 descreve escopo futuro, não estado entregue 🚨
- **Seção afetada:** `Fase 1.6 — Interface Web`
- **Doc diz:** "Analysis new: input de handle + seleção de playbooks"
- **O que o código tem:** formulário atual só expõe `max_posts`; `AnalysesController` permite apenas `:max_posts`; não há modelos/rotas de Playbook.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- - Analysis new: input de handle + seleção de playbooks que receberão a análise
+ - Analysis new: input de handle já definido pelo competitor + seleção de max_posts (30/50/80/100)
```

#### Divergência 3: componentes previstos não existem no app 🚨
- **Seção afetada:** `Fase 1.6` → `Components`
- **Doc diz:** "StatusBadgeComponent, SuggestionCardComponent, ProfileMetricsComponent..."
- **O que o código tem:** não existe `app/components/`; implementação atual está em partials ERB (`app/views/analyses/_*.erb` e `app/views/shared/_status_badge.html.erb`).
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- **Components:**
- - `StatusBadgeComponent`, `SuggestionCardComponent`
- - `ProfileMetricsComponent`, `PostRankingComponent`, `ProgressStepsComponent`
+ **Renderização atual:**
+ - Partials ERB em `app/views/analyses/` e `app/views/shared/_status_badge.html.erb`
```

#### Divergência 4: lista de Stimulus controllers diverge do código
- **Seção afetada:** `Fase 1.6` → `Stimulus controllers`
- **Doc diz:** "analysis_status_controller, confirm_controller, tab_controller"
- **O que o código tem:** `api_key_form_controller.js`, `copy_to_clipboard_controller.js`, `hello_controller.js`.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- - `analysis_status_controller`, `copy_to_clipboard_controller`
- - `confirm_controller`, `tab_controller`
+ - `copy_to_clipboard_controller`
+ - `api_key_form_controller`
+ - `hello_controller` (boilerplate)
```

#### Divergência 5: dívida técnica dos 7 specs herdados não está registrada 🚨
- **Seção afetada:** `Fase 1.6a` / transição para próxima etapa
- **Doc diz:** "Resultado: 626+ specs verdes"
- **O que o código tem:** há dívida conhecida informada: 7 specs falhos herdados da 1.6a (origem `cba8588`), sem menção no roadmap.
- **Tipo:** (c) decisão tomada mas não documentada
- **Patch proposto:**
```diff
+ ### Dívida técnica aberta (pós-1.6a)
+ - 7 specs falhos herdados desde o commit `cba8588` (migração ENV → ApiCredential)
+ - Não bloqueou merge histórico; deve ser tratado em T4.5 (estabilização da suíte)
```

#### Divergência 6: ausência da etapa T4.5 e de T5 explícita 🚨
- **Seção afetada:** entre Fase 1.6 e Fase 1.7
- **Doc diz:** não existe T4.5/T5 explícitas.
- **O que o código tem:** fase web já avançou além de "pronta pra iniciar" e falta etapa de estabilização/testes como marco próprio.
- **Tipo:** (b) fase não marcada como concluída
- **Patch proposto:**
```diff
+ ## Fase 1.6 T4.5 — Estabilização da suíte
+ - Objetivo: zerar falhas herdadas da 1.6a (commit `cba8588`) e normalizar baseline de testes.
+
+ ## Fase 1.6 T5 — System spec end-to-end + polimento de empty states
+ - Objetivo: consolidar fluxo crítico completo no browser e melhorar estados vazios.
```

### docs/01_ARQUITETURA.md

#### Divergência 1: lista de gems principais não bate com Gemfile real 🚨
- **Seção afetada:** `Gems principais`
- **Doc diz:** `gem 'ruby-openai', '8.3.0'` e `gem 'anthropic', '1.35.0'` pinadas no Gemfile.
- **O que o código tem:** Gemfile está sem pin explícito para essas duas gems e inclui `assemblyai` (não listada nessa seção).
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- gem 'ruby-openai', '8.3.0'
- gem 'anthropic', '1.35.0'
+ gem 'ruby-openai'
+ gem 'anthropic'
+ gem 'assemblyai', '~> 1.0'
```

#### Divergência 2: ADR-001 descreve shape incorreto de `Scraping::Result` 🚨
- **Seção afetada:** `ADR-001` → `Shape do Scraping::Result`
- **Doc diz:** `result.error_code` e `profile_data[:biography]`.
- **O que o código tem:** `Scraping::Result` expõe `error` e `message` (sem `error_code`); parser usa `profile_data[:bio]`.
- **Tipo:** (d) campo/enum divergente
- **Patch proposto:**
```diff
- result.error_code      # => Symbol | nil
+ result.message         # => String | nil

- biography: String,
+ bio: String,
```

#### Divergência 3: ADR-006 afirma campo criptografado em modelo inexistente 🚨
- **Seção afetada:** `ADR-006` → `Campos encryptados atualmente`
- **Doc diz:** "OwnProfile#meta_access_token" como campo atual.
- **O que o código tem:** não existe tabela/model `own_profiles`; apenas `ApiCredential#encrypted_api_key` está no schema.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- - `OwnProfile#meta_access_token` — token Meta Graph API
+ - (`OwnProfile#meta_access_token`) previsto para Fase 3.1; ainda não implementado no schema atual
```

#### Divergência 4: ADR-013 enum de validação usa nomes antigos 🚨
- **Seção afetada:** `ADR-013` (schema de `api_credentials`)
- **Doc diz:** `unknown | valid | invalid | quota_exceeded`
- **O que o código tem:** `unknown | verified | failed | quota_exceeded`.
- **Tipo:** (d) campo/enum divergente
- **Patch proposto:**
```diff
- last_validation_status ... unknown | valid | invalid | quota_exceeded
+ last_validation_status ... unknown | verified | failed | quota_exceeded
```

#### Divergência 5: ADR-013 atribui resolução ao Gateway, mas ela está nos Steps 🚨
- **Seção afetada:** `ADR-013` → "Resolução de provider no LLM::Gateway"
- **Doc diz:** gateway resolve provider/chave a partir de account/use_case.
- **O que o código tem:** `AnalyzeStep` e `GenerateSuggestionsStep` resolvem provider/model/key; `LLM::Gateway` recebe `provider:` e `api_key:` já resolvidos.
- **Tipo:** (c) decisão tomada mas não documentada
- **Patch proposto:**
```diff
- #### 3. Resolução de provider no `LLM::Gateway`
+ #### 3. Resolução de provider nos Steps (`AnalyzeStep` / `GenerateSuggestionsStep` / `TranscribeStep`)
```

### docs/02_PADROES_CODIGO.md

#### Divergência 1: regra "zero CSS customizado" conflita com código atual 🚨
- **Seção afetada:** `Frontend` → `CSS e estilo`
- **Doc diz:** "Não adicionar arquivos `.css` customizados".
- **O que o código tem:** `app/assets/tailwind/application.css` com bloco `@theme` extenso (tokens customizados de design system).
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- - Não adicionar arquivos `.css` ou `.scss` customizados
+ - Não criar classes CSS utilitárias próprias (`.btn`, `.card`) nem usar `@apply`
+ - Tokens de tema em `app/assets/tailwind/application.css` via `@theme` são permitidos
```

#### Divergência 2: caminho do CSS mencionado não existe
- **Seção afetada:** exemplo "Errado (em `application.tailwind.css`)"
- **Doc diz:** referência a `application.tailwind.css`.
- **O que o código tem:** arquivo real é `app/assets/tailwind/application.css`.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- application.tailwind.css
+ app/assets/tailwind/application.css
```

#### Divergência 3: seção de gems pinadas contradiz o Gemfile real 🚨
- **Seção afetada:** `Gems com versão pinada`
- **Doc diz:** versões travadas no Gemfile para `ruby-openai` e `anthropic`.
- **O que o código tem:** Gemfile sem pin explícito; versões travadas só no lockfile atual.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- versões travadas exatas no Gemfile
+ versões atualmente resolvidas no Gemfile.lock (revisar em cada upgrade)
```

#### Divergência 4: convenções de services/workers listam classes inexistentes 🚨
- **Seção afetada:** `Convenções de naming` (services/workers)
- **Doc diz:** `Analyses::CritiqueAndRefineStep`, `Transcription::OpenAIProvider`, `Notifications::SendEmailWorker`.
- **O que o código tem:** não existe `CritiqueAndRefineStep`; classe real é `Transcription::Providers::OpenAI`; não existe `Notifications::SendEmailWorker`.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- Analyses::CritiqueAndRefineStep
- Transcription::OpenAIProvider
- Notifications::SendEmailWorker
+ (remover exemplos inexistentes ou marcar como fases futuras)
+ Transcription::Providers::OpenAI
```

#### Divergência 5: tabela de ENV vars contém variáveis removidas e omite as atuais 🚨
- **Seção afetada:** `ENV vars`
- **Doc diz:** `TRANSCRIPTION_PROVIDER`, `TRANSCRIPTION_MODEL`, `DEFAULT_LLM_PROVIDER` (deprecated) e nota de remoção de `SCRAPING_POSTS_PER_ANALYSIS`.
- **O que o código tem:** essas deprecated não estão no `.env.example`; `SCRAPING_POSTS_PER_ANALYSIS` está presente; há variáveis de backup R2 não listadas.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- incluir TRANSCRIPTION_PROVIDER / TRANSCRIPTION_MODEL / DEFAULT_LLM_PROVIDER
- remover SCRAPING_POSTS_PER_ANALYSIS
+ remover deprecated já ausentes
+ manter SCRAPING_POSTS_PER_ANALYSIS
+ adicionar BACKUP_S3_* conforme `.env.example`
```

### docs/05_GLOSSARIO.md

#### Divergência 1: pipeline descrito inclui refinement inexistente 🚨
- **Seção afetada:** `Termos de domínio` (`Analysis`, `ContentSuggestion`, `Use Case`)
- **Doc diz:** "+ refine", `CritiqueAndRefineStep`, use_case `critique_and_refine`.
- **O que o código tem:** worker atual termina em `GenerateSuggestionsStep`; não há `CritiqueAndRefineStep` nem use_case ativo de refinement.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- scrape + metrics + score + transcribe + analyze + generate + refine
+ scrape + metrics + score + transcribe + analyze + generate
```

#### Divergência 2: schema de `posts.post_type` está com tipo incorreto 🚨
- **Seção afetada:** `Schema Post`
- **Doc diz:** `t.string :post_type, null: false`
- **O que o código tem:** `db/schema.rb` usa `t.integer "post_type", null: false` com enum no model.
- **Tipo:** (d) campo/enum divergente
- **Patch proposto:**
```diff
- t.string :post_type, null: false
+ t.integer :post_type, null: false
```

#### Divergência 3: schema de `content_suggestions.content_type` está com tipo incorreto 🚨
- **Seção afetada:** `Schema ContentSuggestion`
- **Doc diz:** `t.string :content_type, null: false`
- **O que o código tem:** `db/schema.rb` usa `t.integer "content_type", null: false`.
- **Tipo:** (d) campo/enum divergente
- **Patch proposto:**
```diff
- t.string :content_type, null: false
+ t.integer :content_type, null: false
```

#### Divergência 4: `refinement_notes` não existe no schema atual 🚨
- **Seção afetada:** `Schema ContentSuggestion` + seções de refinamento
- **Doc diz:** coluna `t.jsonb :refinement_notes` e fluxo de atualização dessa coluna.
- **O que o código tem:** coluna inexistente em `db/schema.rb`; model `ContentSuggestion` não referencia esse campo.
- **Tipo:** (d) campo/enum divergente
- **Patch proposto:**
```diff
- t.jsonb :refinement_notes
- notas de refinamento do CritiqueAndRefineStep
+ (remover do estado atual; manter apenas em seção futura, se necessário)
```

#### Divergência 5: enum `Analysis#status` ainda lista `refining` 🚨
- **Seção afetada:** `Enums` → `Analysis#status`
- **Doc diz:** inclui `refining: 6`.
- **O que o código tem:** enum atual removeu `refining`; índice 6 está reservado e `completed`/`failed` são 7/8.
- **Tipo:** (d) campo/enum divergente
- **Patch proposto:**
```diff
- refining: 6,
+ # índice 6 reservado (status refining removido)
```

#### Divergência 6: enum `ApiCredential#last_validation_status` com labels antigos 🚨
- **Seção afetada:** `Enums` → `ApiCredential#last_validation_status`
- **Doc diz:** `valid` e `invalid`.
- **O que o código tem:** `verified` e `failed`.
- **Tipo:** (d) campo/enum divergente
- **Patch proposto:**
```diff
- valid: 1
- invalid: 2
+ verified: 1
+ failed: 2
```

#### Divergência 7: seção de naming lista classes/arquivos que não existem
- **Seção afetada:** `Convenções de naming` (services/workers/viewcomponents/migrations)
- **Doc diz:** `Analyses::CritiqueAndRefineStep`, `Notifications::SendEmailWorker`, ViewComponents e migration `20260420123458_add_refining_status_to_analyses.rb`.
- **O que o código tem:** esses artefatos não existem; arquivo real de migration é `20260419161251_add_max_posts_and_refining_status_to_analyses.rb`.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- exemplos com classes/migrations inexistentes
+ exemplos refletindo apenas arquivos existentes hoje
```

#### Divergência 8: tabela de ENV e histórico final contradizem `.env.example` 🚨
- **Seção afetada:** `ENV vars` + rodapé de última atualização
- **Doc diz:** deprecated envs ainda listadas e "Removido: ENV SCRAPING_POSTS_PER_ANALYSIS".
- **O que o código tem:** `.env.example` mantém `SCRAPING_POSTS_PER_ANALYSIS=30`; deprecated não aparecem.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- Removido: ENV `SCRAPING_POSTS_PER_ANALYSIS`
+ Mantido: ENV `SCRAPING_POSTS_PER_ANALYSIS` (default 30)
```

### docs/00_NORTE.md

#### Divergência 1: integração MVP "terreno preparado" não existe no código atual 🚨
- **Seção afetada:** `Relação com o Fifty CRM`
- **Doc diz:** "Apenas o terreno é preparado (namespace `/api/v1/`, modelo `ApiToken` vazio, estrutura de serializers)."
- **O que o código tem:** `routes.rb` sem `/api/v1`; não há model `ApiToken` nem pasta de serializers usada.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- terreno preparado com `/api/v1/`, `ApiToken` e serializers
+ integração com Fifty ainda sem scaffold técnico no repo atual
```

#### Divergência 2: escolha de Playbooks por análise é descrita como funcional no fluxo atual 🚨
- **Seção afetada:** `Sistema de Playbooks`
- **Doc diz:** "A cada análise, o usuário escolhe em quais Playbooks ela contribui."
- **O que o código tem:** não há entidades Playbook nem campos/rotas para seleção.
- **Tipo:** (a) fato desatualizado
- **Patch proposto:**
```diff
- A cada análise, o usuário escolhe em quais Playbooks ela contribui.
+ (Planejado para fases futuras: associação de análise a Playbooks ainda não implementada.)
```

## Checklist dos pontos de atenção solicitados

### `docs/03_ROADMAP_FASES.md`
- Fases 0, 1.1, 1.2, 1.3, 1.4, 1.5a, 1.5b, 1.6a marcadas como concluídas? **Sim**.
- Fase 1.6 com T1/T2/T3/T4 detalhadas e concluídas? **Não**.
- Registro da dívida técnica dos 7 specs falhos (commit `cba8588`)? **Não**.
- Menção a T4.5 (estabilização da suíte) entre T4 e T5? **Não**.
- T5 definida como system spec end-to-end + empty states? **Não** (não há T5 explícita).
- "Status atual" no topo bate com a realidade? **Não**.

### `docs/01_ARQUITETURA.md`
- ADR-001 (`scrape_profile(handle:, max_posts:)`) bate com código? **Parcial** (assinatura bate; shape de `Result` diverge).
- ADR-008 (OpenAI + AssemblyAI implementados) bate? **Sim, providers existem**.
- ADR-010 (pipeline serial) bate? **Sim**.
- ADR-013 (`ApiCredential` + `Account#llm_preferences`) bate? **Parcial** (estrutura geral bate; enum e local de resolução divergem).
- Gems principais listadas batem com Gemfile? **Não**.
- Stack Ruby/Rails bate? **Sim** (`ruby 3.3.6`, `rails ~> 7.1.6`).

### `docs/02_PADROES_CODIGO.md`
- "Gems com versão pinada" bate com Gemfile.lock? **Parcial** (lock atual coincide, mas doc afirma pin explícito no Gemfile e isso não ocorre).
- "Inflections registrados" bate com `config/initializers/inflections.rb`? **Sim** (`LLM`, `AI`).
- Padrões Service Objects/Workers batem com estrutura `app/`? **Parcial** (estrutura existe, mas doc lista classes inexistentes).

### `docs/05_GLOSSARIO.md`
- Schemas das tabelas batem com `db/schema.rb`? **Parcial** (há divergências importantes em tipos e campos).
- Enums listados batem com modelos? **Não** (`Analysis#status` e `ApiCredential#last_validation_status` divergem).
- `Analysis#status` tem `refining`? **Não**, foi removido e índice 6 ficou reservado.
- ENV vars listadas batem com `.env.example`? **Não**.

## Proposta de novas seções a adicionar

### Em `03_ROADMAP_FASES.md`
- Adicionar subseção "Fase 1.6 T4 — concluída" com entregas reais (Turbo Stream, partials, show rico, max_posts no form).
- Adicionar subseção "Fase 1.6 T4.5 — Estabilização da suíte" antes da próxima macrofase.
- Registrar dívida: "7 specs falhos desde commit `cba8588` (migração ENV → ApiCredential)".

### Em `02_PADROES_CODIGO.md` ou `01_ARQUITETURA.md`
- Documentar explicitamente o padrão vigente de renderização de status por Turbo Stream com `broadcast_replace_to` + partials (`analysis_body` e `list_item`).
- Documentar que resolução de provider/model/api_key ocorre hoje nos Steps (não no `LLM::Gateway`).

## Ações sugeridas
1. [ ] Aplicar patches do `docs/03_ROADMAP_FASES.md`
2. [ ] Aplicar patches do `docs/05_GLOSSARIO.md`
3. [ ] Revisar humanamente divergências tipo (c) — decisões não documentadas
4. [ ] Aprovar e fazer commit: `docs: sync /docs/ com estado real pós-T4`
