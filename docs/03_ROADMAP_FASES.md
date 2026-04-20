# Roadmap de Fases — ViralSpy v2

## Fase 1.5b — Pipeline LLM: Transcribe + Analyze + GenerateSuggestions + Worker

### Entregas concluídas

- `TranscribeStep` — transcreve reels selecionados via Transcription::Factory; falha individual não derruba análise
- `AnalyzeStep` — 3 chamadas LLM separadas (reel/carousel/image) via `Analyses::PromptRenderer` + ERBs em disco; salva `analysis.insights`
- `GenerateSuggestionsStep` — resolve mix de conteúdo, chama LLM, persiste 5 `ContentSuggestion`
- `RunAnalysisWorker` — orquestra todos os 6 steps em série; `retry: 0`; abre `ActsAsTenant.with_tenant`
- `Analyses::PromptRenderer` — renderiza ERBs de `app/prompts/{step}/{kind}.erb` com locals
- 8 arquivos ERB em `app/prompts/` (4 pares system/user): `analyze_reels`, `analyze_carousels`, `analyze_images`, `generate_suggestions`

### Débito técnico conhecido (decidido na Fase 1.5b)

Prompts hoje vivem em `app/prompts/*.erb` lidos via `Analyses::PromptRenderer`.
Não há versionamento nem UI de edição. Quando a UI de edição de prompts entrar
no roadmap (estimado Fase 2+), será necessário:

1. Criar model `PromptTemplate` no banco (já foi tentado na Fase 1.5b e revertido)
2. Migrar conteúdo atual dos 8 ERBs para seeds iniciais da tabela, **preservando
   os locals que os steps já passam** (`handle`, `followers`, `profile_metrics`,
   `posts` como AR objects — não `competitor_handle` + hashes)
3. Refatorar `AnalyzeStep` e `GenerateSuggestionsStep` pra ler do banco
4. Atualizar specs dos steps pra seedear templates antes de rodar

Estimativa: ~1 dia de trabalho quando chegar a hora. Custo de manter como está
agora: zero.
