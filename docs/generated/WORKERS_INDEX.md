# Workers Index

Índice de todos os workers Sidekiq em `app/workers/`. Gerado automaticamente — não edite à mão.

---

## Analyses::RunAnalysisWorker

**Path:** `app/workers/analyses/run_analysis_worker.rb`
**Queue:** `analyses`
**Retry:** 0 (pipeline custa ~R$0,35; falha = usuário reroda manualmente)
**Entrada:** `perform(analysis_id)` — `Integer`
**Orquestra:** Pipeline de 6 steps em sequência:
1. `Analyses::ScrapeStep` — scraping do perfil Instagram via Apify
2. `Analyses::ProfileMetricsStep` — cálculo de métricas do perfil
3. `Analyses::ScoreAndSelectStep` — pontuação e seleção dos top posts
4. `Analyses::TranscribeStep` — transcrição de áudio dos Reels selecionados
5. `Analyses::AnalyzeStep` — análise LLM por tipo de post (reel/carousel/image)
6. `Analyses::GenerateSuggestionsStep` — geração de 5 sugestões de conteúdo

Constante: `STEPS = [ScrapeStep, ProfileMetricsStep, ScoreAndSelectStep, TranscribeStep, AnalyzeStep, GenerateSuggestionsStep]`

Cada step retorna `Analyses::Result`; se `failure?`, o worker interrompe o pipeline imediatamente.
**Propósito:** Executa a análise completa de um perfil concorrente do início ao fim. É o único ponto de entrada para o pipeline de análise.

---

## MediaGeneration::PollWorker

**Path:** `app/workers/media_generation/poll_worker.rb`
**Queue:** `media_generation`
**Retry:** 3
**Entrada:** `perform(generated_media_id, attempt = 1)` — `Integer, Integer`
**Orquestra:** Loop de polling com reschedule automático:
- Verifica status do job HeyGen via `MediaGeneration::Providers::Heygen#check_status`
- Se ainda processando: reschedula a si mesmo em 10s (`perform_in(POLL_INTERVAL, id, attempt + 1)`)
- Se completo: atualiza `GeneratedMedia` com `output_url`, `duration_seconds`, `status: :completed`, registra custo via `MediaGenerationUsageLog`
- Se falhou ou excedeu `MAX_ATTEMPTS (60)`: marca `status: :failed`

Constantes: `MAX_ATTEMPTS = 60`, `POLL_INTERVAL = 10` (segundos)

Timeout total máximo: 60 tentativas × 10s = 10 minutos.
**Propósito:** Monitora assincronamente o status de geração de vídeo HeyGen e atualiza o `GeneratedMedia` quando pronto ou falho.
