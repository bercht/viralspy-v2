# 06_ROADMAP_PERFORMANCE — Referência: Fases de Performance, Qualidade e Diferencial

> **Status:** Arquivado como referência. Conteúdo deste doc foi reavaliado pós-Fase 1.6 e redistribuído conforme abaixo. Não iniciar nenhuma fase deste doc sem decisão explícita após Fase 2.4 do roadmap principal.

---

## O que foi absorvido pelo roadmap principal

| Fase original | Destino |
|---|---|
| 4.3 MediaGen HeyGen | Absorvida como **Fase 2.2** (enxuta, só HeyGen) |
| 4.3 MediaGen Freepik | Arquivada → candidata pós-Fase 2.4 |
| 4.5 Higgsfield | Arquivada indefinidamente |

## O que foi arquivado (sem previsão)

| Fase original | Motivo |
|---|---|
| 4.1 Performance (paralelização, retry, cache) | Só vira prioridade se latência incomodar no uso diário real. Pipeline atual de ~4-5min é aceitável pra uso pessoal. |
| 4.2 Embeddings pgvector | Só faz sentido com volume de análises suficiente pra justificar. Reavaliar após 50+ análises no banco. |
| 4.4 Obsidian export | Opcional, uso pessoal. 1-2 dias quando houver disposição. Não é bloqueador de nada. |

---

## Referência — Fase 4.1: Performance do Pipeline

> Preservada aqui para consulta quando virar prioridade. Não é próxima fase.

### Objetivo

Reduzir latência da análise de ~4-5min para ~2-2.5min via paralelização interna de steps + retry idempotente + cache de scraping.

### Decisões já tomadas (ADR-014 a ser criado quando iniciar)

- Paralelismo permitido **apenas dentro de um step**, não entre steps
- Steps continuam seriais entre si
- `TranscribeStep` paraleliza 12 reels em até 4 threads (`Parallel` gem)
- `AnalyzeStep` paraleliza 3 chamadas LLM em 3 threads
- `RunAnalysisWorker` passa de `retry: 0` para `retry: 2` com backoff exponencial
- Cada step ganha `already_completed?` guard pra idempotência em retry
- `ScrapingCache` global (não tenant-scoped), TTL 12h, tabela Postgres simples
- `Post.upsert_all` substitui loop `Post.new + save!` no `ScrapeStep`

### Critérios de aceite (referência)

- `TranscribeStep` roda 12 reels em ≤ 4 threads, latência ~30s (antes ~2min)
- `AnalyzeStep` roda 3 chamadas em paralelo, latência ~12s (antes ~30s)
- Cada step tem `already_completed?` com spec de idempotência
- Latência end-to-end: ~2-2.5min

### Alertas

⚠️ `Parallel.each(in_threads:)` usa threads do processo Sidekiq — não abre workers novos.

⚠️ `Post.upsert_all` bypassa `ActsAsTenant` validations — `account_id` deve ser sempre explícito nas rows.

🚨 Cache global — revisar que `profile_data` contém apenas dados públicos do Instagram antes de implementar.

---

## Referência — Fase 4.2: Embeddings e Busca Semântica (pgvector)

> Preservada aqui para consulta. pgvector já habilitado desde Fase 0. Reavaliar após 50+ análises no banco.

### Objetivo

Indexar posts, transcripts, sugestões e playbooks com embeddings. Evitar sugestões repetidas entre análises. Busca semântica dentro do playbook.

### Decisões já tomadas

- Provider: OpenAI `text-embedding-3-small` (1536 dimensões), BYOK via ADR-013
- Novas colunas: `embedding vector(1536)` em `posts`, `content_suggestions`, `playbook_versions`, `competitors`
- Índice IVFFlat em todas com `lists = 100`
- Novo step `Analyses::EmbedStep` — roda após `GenerateSuggestions`, antes de `UpdatePlaybook`
- Falha do EmbedStep **não derruba pipeline** — feature semântica não funciona, nada crítico
- `Embedding::Search.similar_suggestions` alimenta `GenerateSuggestionsStep` como contexto negativo ("evite repetir")
- `Playbooks::EmbedVersionWorker` async após `PlaybookVersion.create`
- Custo adicional estimado: ~$0.002/análise (barato)

### Alertas

⚠️ `text-embedding-3-small` tem limite 8192 tokens — truncar caption+transcript em ~6000 tokens antes de mandar.

⚠️ IVFFlat com < 10k vetores pode ter recall sub-ótimo. Ajustar `lists` conforme volume crescer.

---

## Referência — Fase 4.3: MediaGen Freepik

> HeyGen foi absorvido pela Fase 2.2. Freepik fica aqui como próximo provider quando HeyGen estiver estável.

### Decisões já tomadas

- Mesma arquitetura `MediaGeneration::BaseProvider` da Fase 2.2
- Adicionar `MediaGeneration::Providers::Freepik` à `Factory::REGISTRY`
- Adicionar `freepik` ao enum `ApiCredential#provider`
- Models de `kling_v2.1_pro` (vídeo) e `flux_dev` (imagem) como defaults

### Gate de início

Só iniciar Freepik depois de:
1. Fase 2.2 (HeyGen) mergeada e estável
2. Insatisfação concreta com HeyGen (avatar genérico, sem opção de cena real) — se HeyGen serve bem, Freepik não é prioridade

---

## Referência — Fase 4.4: Obsidian Export

> Feature pessoal, opcional. 1-2 dias quando houver disposição. Não depende de nenhuma outra fase.

### Escopo resumido

- `ObsidianIntegration` (account, encrypted_api_key, local_rest_api_url, vault_path_prefix)
- `Obsidian::Export` service — analysis + playbook_version → markdown com frontmatter YAML
- Template ERB com frontmatter compatível com Dataview
- Trigger manual (botão) + opcional automático (checkbox na criação de análise)
- Falha de conexão (Obsidian offline) não derruba análise

### Alerta principal

⚠️ Local REST API só funciona se Obsidian estiver rodando na máquina local. VPS não alcança `127.0.0.1:27124`. Opção mais simples pra uso pessoal: rodar ViralSpy localmente (`docker compose -f docker-compose.dev.yml up`) quando quiser exportar em lote.

---

**Última atualização:** Reavaliação pós-Fase 1.6. Fase 4.3 HeyGen absorvida pelo roadmap principal (Fase 2.2). Fases 4.1, 4.2, 4.4 arquivadas como referência com decisões preservadas. Fase 4.5 Higgsfield arquivada indefinidamente.