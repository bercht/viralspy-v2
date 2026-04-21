# Services Index

Índice de todos os services em `app/services/`. Gerado automaticamente — não edite à mão.

---

## Analyses::

### Analyses::ScrapeStep

**Path:** `app/services/analyses/scrape_step.rb`
**Entrada:** `call(analysis)` — `Analysis`
**Saída:** `Analyses::Result`
**Propósito:** Executa scraping do perfil Instagram via `Scraping::Factory`, persiste posts e atualiza dados do competitor. Step 1 do pipeline de análise.
**Chama:** `Scraping::Factory.build`, `Analyses::Result`

---

### Analyses::ProfileMetricsStep

**Path:** `app/services/analyses/profile_metrics_step.rb`
**Entrada:** `call(analysis)` — `Analysis`
**Saída:** `Analyses::Result`
**Propósito:** Calcula métricas agregadas do perfil a partir dos posts scraped: posts_per_week, content_mix, avg_engagement_rate, top_hashtags, best_posting_days/hours, consistency_score. Persiste em `analysis.profile_metrics`. Step 2 do pipeline.
**Chama:** `Analyses::Result`

---

### Analyses::ScoreAndSelectStep

**Path:** `app/services/analyses/score_and_select_step.rb`
**Entrada:** `call(analysis)` — `Analysis`
**Saída:** `Analyses::Result`
**Propósito:** Pontua todos os posts via `Scoring::Formula` e seleciona os top por tipo via `Scoring::Selector`. Step 3 do pipeline.
**Chama:** `Analyses::Scoring::Formula`, `Analyses::Scoring::Selector`, `Analyses::Result`

---

### Analyses::TranscribeStep

**Path:** `app/services/analyses/transcribe_step.rb`
**Entrada:** `call(analysis)` — `Analysis`
**Saída:** `Analyses::Result`
**Propósito:** Transcreve áudio dos Reels selecionados via provider configurado na conta (BYOK). Posts não-reel são marcados como `:skipped`. Step 4 do pipeline.
**Chama:** `Transcription::Factory`, `Transcription::UsageLogger`, `Analyses::Result`

---

### Analyses::AnalyzeStep

**Path:** `app/services/analyses/analyze_step.rb`
**Entrada:** `call(analysis)` — `Analysis`
**Saída:** `Analyses::Result`
**Propósito:** Analisa posts selecionados por tipo (reel, carousel, image) via LLM, extrai insights (hooks, estruturas, CTAs, temas) e persiste em `analysis.insights`. Step 5 do pipeline. Constante `MAX_TOKENS = 2000`.
**Chama:** `Analyses::PromptRenderer`, `LLM::Gateway`, `Analyses::Result`

---

### Analyses::GenerateSuggestionsStep

**Path:** `app/services/analyses/generate_suggestions_step.rb`
**Entrada:** `call(analysis)` — `Analysis`
**Saída:** `Analyses::Result`
**Propósito:** Gera 5 sugestões de conteúdo original (não cópias) com base nos insights extraídos, persiste como `ContentSuggestion`. Mix padrão: 2 reels + 2 carousels + 1 image. Step 6 do pipeline. Constantes `TARGET_COUNT = 5`, `MAX_TOKENS = 4000`.
**Chama:** `Analyses::PromptRenderer`, `LLM::Gateway`, `ContentSuggestion`, `Analyses::Result`

---

### Analyses::UpdatePlaybookStep

**Path:** `app/services/analyses/update_playbook_step.rb`
**Entrada:** `call(analysis_playbook)` — `AnalysisPlaybook`
**Saída:** `Analyses::Result`
**Propósito:** Atualiza um Playbook com novos insights da análise e feedbacks pendentes via LLM. Cria nova `PlaybookVersion`, incorpora feedbacks e incrementa `current_version_number`. Constante `MAX_TOKENS = 4000`, separador `---DIFF_SUMMARY---`.
**Chama:** `Analyses::PromptRenderer`, `LLM::Gateway`, `PlaybookVersion`, `PlaybookFeedback`, `Analyses::Result`

---

### Analyses::PromptRenderer

**Path:** `app/services/analyses/prompt_renderer.rb`
**Entrada:** `render(step:, kind:, locals: {})` — `String, Symbol, Hash`
**Saída:** `String` (prompt renderizado)
**Propósito:** Renderiza templates ERB de `app/prompts/{step}/{kind}.erb` com locals injetados via binding. Módulo utilitário sem estado.
**Chama:** —

---

### Analyses::Result

**Path:** `app/services/analyses/result.rb`
**Entrada:** `success(data: {})` / `failure(error:, error_code: nil)`
**Saída:** `Analyses::Result`
**Propósito:** Value object de resultado para todos os steps do pipeline. Métodos: `success?`, `failure?`, `data`, `error`, `error_code`.
**Chama:** —

---

### Analyses::Scoring::Formula

**Path:** `app/services/analyses/scoring/formula.rb`
**Entrada:** `calculate(post:, followers:)` — `Post, Integer`
**Saída:** `Float` (quality_score)
**Propósito:** Calcula pontuação de qualidade de um post com base em engajamento ponderado (curtidas + comentários×3), taxa de engajamento por follower e fator de maturidade temporal (1–7 dias). Posts com menos de 3 interações ou menos de 6h recebem 0. Constantes: `MIN_INTERACTIONS = 3`, `MIN_AGE = 6.hours`.
**Chama:** —

---

### Analyses::Scoring::Selector

**Path:** `app/services/analyses/scoring/selector.rb`
**Entrada:** `select_count(post_type, max_posts)` — `Symbol/String, Integer`
**Saída:** `Integer` (quantidade de posts a selecionar)
**Propósito:** Determina quantos posts de cada tipo selecionar para análise LLM, aplicando ratios (reel: 40%, carousel: 17%, image: 10%) e caps absolutos (reel: 20, carousel: 8, image: 5).
**Chama:** —

---

## LLM::

### LLM::Gateway

**Path:** `app/services/llm/gateway.rb`
**Entrada:** `complete(provider:, model:, messages:, use_case:, account:, api_key:, system: nil, json_mode: false, temperature: 0.7, max_tokens: ..., analysis: nil)` — vários tipos
**Saída:** `LLM::Response`
**Propósito:** Ponto central de chamada LLM. Valida args, instancia provider (OpenAI ou Anthropic), executa completion e chama UsageLogger. Providers suportados: `:openai`, `:anthropic`.
**Chama:** `LLM::Providers::OpenAI`, `LLM::Providers::Anthropic`, `LLM::UsageLogger`

---

### LLM::Providers::Base

**Path:** `app/services/llm/providers/base.rb`
**Entrada:** —
**Saída:** —
**Propósito:** Classe base abstrata para providers LLM. Define constante `DEFAULT_MAX_TOKENS` e interface `#complete`.
**Chama:** —

---

### LLM::Providers::OpenAI

**Path:** `app/services/llm/providers/open_ai.rb`
**Entrada:** `new(api_key:)`, `complete(model:, messages:, system:, json_mode:, temperature:, max_tokens:)`
**Saída:** `LLM::Response`
**Propósito:** Adapter para OpenAI Chat Completions API.
**Chama:** `LLM::Response`

---

### LLM::Providers::Anthropic

**Path:** `app/services/llm/providers/anthropic.rb`
**Entrada:** `new(api_key:)`, `complete(model:, messages:, system:, json_mode:, temperature:, max_tokens:)`
**Saída:** `LLM::Response`
**Propósito:** Adapter para Anthropic Messages API (Claude).
**Chama:** `LLM::Response`

---

### LLM::Response

**Path:** `app/services/llm/response.rb`
**Entrada:** `new(content:, raw:, usage:, model:, provider:, finish_reason: nil)`
**Saída:** Instância com `content`, `prompt_tokens`, `completion_tokens`, `total_tokens`, `parsed_json`
**Propósito:** Value object que encapsula resposta LLM. `parsed_json` sanitiza markdown fences antes de fazer `JSON.parse`, levanta `LLM::ResponseParseError` se falhar.
**Chama:** —

---

### LLM::UsageLogger

**Path:** `app/services/llm/usage_logger.rb`
**Entrada:** `log(response:, account:, use_case:, analysis: nil)` — `LLM::Response, Account, String, Analysis?`
**Saída:** `LLMUsageLog` (criado)
**Propósito:** Persiste custo e tokens de cada chamada LLM em `llm_usage_logs`. Calcula custo via `LLM::Pricing`.
**Chama:** `LLM::Pricing`, `LLMUsageLog`

---

### LLM::Pricing

**Path:** `app/services/llm/pricing.rb`
**Entrada:** `cost_cents(provider:, model:, prompt_tokens:, completion_tokens:)` — (inferido)
**Saída:** `Integer` (centavos BRL)
**Propósito:** Calcula custo em centavos BRL por chamada LLM com base em tabela de preços por token. (inferido)
**Chama:** —

---

### LLM::Error (e variantes)

**Path:** `app/services/llm/error.rb` e arquivos adjacentes
**Propósito:** Hierarquia de erros LLM: `LLM::Error` (base), `MissingApiKeyError`, `ProviderNotFoundError`, `InvalidRequestError`, `AuthenticationError`, `ModelNotFoundError`, `RateLimitError`, `TimeoutError`, `ResponseParseError`.
**Chama:** —

---

## Scraping::

### Scraping::Factory

**Path:** `app/services/scraping/factory.rb`
**Entrada:** `build(provider: ENV["SCRAPING_PROVIDER"] || "apify")` — `String`
**Saída:** `Scraping::ApifyProvider` (ou raise `UnknownProviderError`)
**Propósito:** Instancia o provider de scraping correto pelo nome. Atualmente suporta apenas `"apify"`.
**Chama:** `Scraping::ApifyProvider`

---

### Scraping::ApifyProvider

**Path:** `app/services/scraping/apify_provider.rb`
**Entrada:** `scrape_profile(handle:, max_posts:)` — `String, Integer`
**Saída:** `Scraping::Result`
**Propósito:** Executa scraping via Apify em dois runs: profile scraper + post scraper. Retry automático em `RateLimitError` e `TimeoutError` (máximo 2 tentativas). Constantes: `PROFILE_ACTOR_ID`, `POST_ACTOR_ID`.
**Chama:** `Scraping::Apify::Client`, `Scraping::Apify::Parser`, `Scraping::Apify::RunPoller`, `Scraping::Result`

---

### Scraping::BaseProvider

**Path:** `app/services/scraping/base_provider.rb`
**Entrada:** `scrape_profile(handle:, max_posts:)` — interface abstrata
**Saída:** —
**Propósito:** Classe base com método abstrato `#scrape_profile` e helper `#validate_handle!` que normaliza e valida Instagram handles.
**Chama:** —

---

### Scraping::Apify::Client

**Path:** `app/services/scraping/apify/client.rb`
**Entrada:** `start_run(actor_id:, input:)`, `get_dataset_items(run_id)` — (inferido da usage)
**Saída:** Hash (resposta JSON Apify)
**Propósito:** HTTP client para a Apify API. Inicia runs e busca items de dataset. (inferido)
**Chama:** —

---

### Scraping::Apify::Parser

**Path:** `app/services/scraping/apify/parser.rb`
**Entrada:** `parse_profile(item)`, `parse_posts(items)` — Hash, Array
**Saída:** Hash (profile_data), Array<Hash> (posts)
**Propósito:** Transforma respostas brutas da Apify no schema interno de `profile_data` e array de hashes de post. (inferido)
**Chama:** —

---

### Scraping::Apify::RunPoller

**Path:** `app/services/scraping/apify/run_poller.rb`
**Entrada:** `new(client:, run_id:, sleeper:)`, `wait_for_completion!`
**Saída:** Aguarda até run completar ou levanta erro
**Propósito:** Poll de status de run Apify, com suporte a sleeper injetável para testes. Levanta `RunFailedError` ou `TimeoutError` conforme resultado. (inferido)
**Chama:** `Scraping::Apify::Client`

---

### Scraping::Result

**Path:** `app/services/scraping/result.rb`
**Entrada:** `success(posts:, profile_data:, run_id: nil)` / `failure(error:, message: nil, run_id: nil)`
**Saída:** Instância com `posts`, `profile_data`, `error`, `message`, `run_id`, `success?`, `failure?`
**Propósito:** Value object de resultado do scraping.
**Chama:** —

---

### Scraping::Error (e variantes)

**Path:** `app/services/scraping/error.rb` e arquivos adjacentes
**Propósito:** Hierarquia de erros de scraping: `Scraping::Error` (base), `EmptyDatasetError`, `ParseError`, `ProfileNotFoundError`, `RateLimitError`, `RunFailedError`, `TimeoutError`.
**Chama:** —

---

## Transcription::

### Transcription::Factory

**Path:** `app/services/transcription/factory.rb`
**Entrada:** `build(provider:, api_key:)` — `String, String`
**Saída:** `Transcription::Providers::OpenAI` ou `Transcription::Providers::AssemblyAI`
**Propósito:** Instancia provider de transcrição pelo nome. Suporta `"openai"` e `"assemblyai"`.
**Chama:** `Transcription::Providers::OpenAI`, `Transcription::Providers::AssemblyAI`

---

### Transcription::Providers::OpenAI

**Path:** `app/services/transcription/providers/open_ai.rb`
**Entrada:** `new(api_key:)`, `transcribe(video_url:)` — `String`
**Saída:** `Transcription::Result`
**Propósito:** Adapter para OpenAI Whisper / GPT transcription. Faz download do vídeo e envia para API. (inferido)
**Chama:** `Transcription::Result`

---

### Transcription::Providers::AssemblyAI

**Path:** `app/services/transcription/providers/assembly_ai.rb`
**Entrada:** `new(api_key:)`, `transcribe(video_url:)` — `String`
**Saída:** `Transcription::Result`
**Propósito:** Adapter para AssemblyAI transcription API. (inferido)
**Chama:** `Transcription::Result`

---

### Transcription::BaseProvider

**Path:** `app/services/transcription/base_provider.rb`
**Entrada:** —
**Saída:** —
**Propósito:** Classe base abstrata para providers de transcrição. (inferido)
**Chama:** —

---

### Transcription::UsageLogger

**Path:** `app/services/transcription/usage_logger.rb`
**Entrada:** `log(result:, account:, provider:, model:, post: nil, analysis: nil)` — vários tipos
**Saída:** `TranscriptionUsageLog` (criado) ou `nil` se falha
**Propósito:** Persiste custo e duração de cada transcrição em `transcription_usage_logs`. Calcula custo via `Transcription::Pricing`. No-op silencioso se `result.failure?`.
**Chama:** `Transcription::Pricing`, `TranscriptionUsageLog`

---

### Transcription::Pricing

**Path:** `app/services/transcription/pricing.rb`
**Entrada:** `cost_cents(provider:, model:, duration_seconds:)` — `Symbol, String, Integer`
**Saída:** `Integer` (centavos BRL)
**Propósito:** Calcula custo de transcrição em centavos BRL. Tabela: OpenAI `gpt-4o-mini-transcribe` = USD$0.003/min × taxa BRL 5.50. Retorna 0 para modelos desconhecidos.
**Chama:** —

---

### Transcription::Result

**Path:** `app/services/transcription/result.rb`
**Entrada:** `success(transcript:, duration_seconds:)` / `failure(error:, error_code:)`
**Saída:** Instância com `transcript`, `duration_seconds`, `error`, `error_code`, `success?`, `failure?`
**Propósito:** Value object de resultado de transcrição.
**Chama:** —

---

### Transcription::Error (e variantes)

**Path:** `app/services/transcription/error.rb` e arquivos adjacentes
**Propósito:** Hierarquia de erros: `Transcription::Error` (base), `AuthenticationError`, `MissingApiKeyError`, `ProviderNotFoundError`, `RateLimitError`, `TimeoutError`, `ResponseParseError`, `DownloadError`, `FileTooLargeError`.
**Chama:** —

---

## MediaGeneration::

### MediaGeneration::Factory

**Path:** `app/services/media_generation/factory.rb`
**Entrada:** `build(provider:, api_key:)` — `String, String`
**Saída:** `MediaGeneration::Providers::Heygen`
**Propósito:** Instancia provider de geração de mídia pelo nome. Constante `PROVIDERS = { "heygen" => "MediaGeneration::Providers::Heygen" }`. Lança `Errors::Base` para provider desconhecido.
**Chama:** `MediaGeneration::Providers::Heygen`

---

### MediaGeneration::Start

**Path:** `app/services/media_generation/start.rb`
**Entrada:** `call(content_suggestion:, account:, script: nil, avatar_id: nil, voice_id: nil)` — `ContentSuggestion, Account, String?, String?, String?`
**Saída:** `MediaGeneration::Start::Outcome` (Struct com `success`, `generated_media`, `error`, `error_code`)
**Propósito:** Orquestra criação de vídeo avatar HeyGen: resolve API key e settings da conta, constrói script via `ScriptBuilder` (se não fornecido), chama provider, persiste `GeneratedMedia` e enfileira `PollWorker` em 10s.
**Chama:** `MediaGeneration::Factory`, `MediaGeneration::ScriptBuilder`, `MediaGeneration::PollWorker`, `GeneratedMedia`

---

### MediaGeneration::ScriptBuilder

**Path:** `app/services/media_generation/script_builder.rb`
**Entrada:** `build(suggestion:)` — `ContentSuggestion`
**Saída:** `String` (script para vídeo, máx 1500 chars)
**Propósito:** Constrói roteiro de vídeo a partir de uma `ContentSuggestion`: formata hook, limpa caption (remove hashtags, @mentions, URLs) e adiciona CTA padrão se não houver. Trunca em 1500 chars.
**Chama:** —

---

### MediaGeneration::Providers::Heygen

**Path:** `app/services/media_generation/providers/heygen.rb`
**Entrada:** `new(api_key:)`, `start_generation(script:, avatar_id:, voice_id:, title:)`, `check_status(job_id:)`, `validate_api_key`, `fetch_avatars`, `fetch_voices(language: nil)`
**Saída:** `MediaGeneration::Result`
**Propósito:** Adapter HTTP para HeyGen API v2. Gerencia criação de vídeos avatar, polling de status e validação de key.
**Chama:** `MediaGeneration::Result`

---

### MediaGeneration::BaseProvider

**Path:** `app/services/media_generation/base_provider.rb`
**Entrada:** —
**Saída:** —
**Propósito:** Classe base abstrata para providers de geração de mídia. (inferido)
**Chama:** —

---

### MediaGeneration::Result

**Path:** `app/services/media_generation/result.rb`
**Entrada:** `new(success:, job_id: nil, output_url: nil, status: nil, duration_seconds: nil, error: nil, error_code: nil)`
**Saída:** Instância com `job_id`, `output_url`, `status`, `duration_seconds`, `error`, `error_code`, `success?`, `failure?`
**Propósito:** Value object de resultado para operações de geração de mídia.
**Chama:** —

---

### MediaGeneration::Errors::Base

**Path:** `app/services/media_generation/errors.rb`
**Propósito:** Hierarquia de erros de geração de mídia. `Errors::Base` é a raiz.
**Chama:** —

---

## ApiCredentials::

### ApiCredentials (módulo de erros)

**Path:** `app/services/api_credentials.rb`
**Propósito:** Define erros do namespace: `ApiCredentials::Error` (base), `AuthenticationError`, `QuotaExceededError`, `UnknownError`, `NotConfiguredError` (com attrs `provider` e `use_case`).
**Chama:** —

---

### ApiCredentials::ValidateService

**Path:** `app/services/api_credentials/validate_service.rb`
**Entrada:** `call(credential)` — `ApiCredential`
**Saída:** `ApiCredentials::Result`
**Propósito:** Valida uma API key contra o provider real (OpenAI, Anthropic, AssemblyAI, HeyGen) com timeout de 15s. Persiste `last_validation_status` e `last_validated_at` na credential.
**Chama:** `ApiCredentials::Result`, `MediaGeneration::Providers::Heygen` (para validação HeyGen)

---

### ApiCredentials::Result

**Path:** `app/services/api_credentials/result.rb`
**Entrada:** `success(message: ...)` / `failure(status:, message:)`
**Saída:** Instância com `status` (`:verified`, `:failed`, `:quota_exceeded`, `:unknown`), `message`, `success?`, `failure?`
**Propósito:** Value object de resultado de validação de credential.
**Chama:** —

---

## Playbooks::

### Playbooks::GenerateSuggestionsService

**Path:** `app/services/playbooks/generate_suggestions_service.rb`
**Entrada:** `call(playbook:, content_type:, quantity:)` — `Playbook, String, Integer`
**Saída:** `Analyses::Result`
**Propósito:** Gera sugestões de conteúdo para um Playbook via LLM (prompt `playbook_suggestions`), persiste como `PlaybookSuggestion`. Requer `current_version_number > 0` (playbook com conteúdo). Usa group `generation` das preferences da conta.
**Chama:** `Analyses::PromptRenderer`, `LLM::Gateway`, `PlaybookSuggestion`, `Analyses::Result`
