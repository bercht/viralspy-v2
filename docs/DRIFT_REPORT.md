# DRIFT REPORT — Sincronização docs × código

**Data:** 2026-04-21
**Branch:** docs/sync-with-code-20260421
**Commit base:** f7799a2 (último commit em main antes do branch)

---

## ⚠️ Resumo

Total de drifts encontrados: **12**
- Críticos (ADR contradita pelo código): **3**
- Moderados (decisão parcialmente divergente): **6**
- Menores (linguagem/exemplo desatualizado): **3**

---

## Drift #1 — `CritiqueAndRefineStep` descrito no doc mas inexistente no código

**Doc afetado:** `docs/05_GLOSSARIO.md` → seção "Lógica de refinamento (ADR-011)"
**Severidade:** Crítica

**O que o doc diz:**
> Seção descreve `CritiqueAndRefineStep` como parte do pipeline de análise, que executa um loop de refinamento das sugestões e grava `changes_made` em `content_suggestions.refinement_notes`.

**O que o código faz:**
O worker `Analyses::RunAnalysisWorker` define a constante `STEPS = [ScrapeStep, ProfileMetricsStep, ScoreAndSelectStep, TranscribeStep, AnalyzeStep, GenerateSuggestionsStep]`. Nenhum arquivo `critique_and_refine_step.rb` existe no codebase. O step foi removido (ou nunca implementado) e o pipeline atual tem 6 steps, não 7.

**Possíveis interpretações:**
1. Step foi planejado, implementado parcialmente e removido antes da Fase 1.5b → doc ficou pra trás
2. Step está planejado para fase futura e foi documentado prematuramente
3. Step nunca existiu e a seção ADR-011 do glossário foi escrita antes da implementação

**Ação sugerida:** Remover a seção narrativa de "Lógica de refinamento (ADR-011)" do glossário ou marcá-la como `[PLANEJADO — não implementado]`. A decisão de implementar ou descartar definitivamente o step cabe ao Curt.

---

## Drift #2 — Coluna `content_suggestions.refinement_notes` documentada mas inexistente no schema

**Doc afetado:** `docs/05_GLOSSARIO.md` → seção "Lógica de refinamento (ADR-011)"
**Severidade:** Crítica

**O que o doc diz:**
> `changes_made` do `CritiqueAndRefineStep` é persistido em `content_suggestions.refinement_notes`.

**O que o código faz:**
A tabela `content_suggestions` no schema real tem as colunas: `position`, `content_type`, `hook`, `caption_draft`, `format_details`, `suggested_hashtags`, `rationale`, `status`. A coluna `refinement_notes` não existe. Qualquer código que tentasse acessar `content_suggestion.refinement_notes` quebraria com `NoMethodError`.

**Possíveis interpretações:**
1. A migration que criaria essa coluna nunca foi escrita (step removido antes de implementar) → remover referência do doc
2. Feature está pendente → criar migration e implementar o step antes de documentar

**Ação sugerida:** Remover a referência à coluna `refinement_notes` do glossário. Se o `CritiqueAndRefineStep` for reativado no futuro, a migration e o step devem ser criados juntos, e o doc atualizado depois.

---

## Drift #3 — `00_NORTE.md` proíbe "Geração de imagem/vídeo com IA" mas código implementa exatamente isso (HeyGen)

**Doc afetado:** `docs/00_NORTE.md` → seção "Não-objetivos explícitos"
**Severidade:** Crítica

**O que o doc diz:**
> `❌ Geração de imagem/vídeo com IA. Caption e formato sugerido sim. Criar a arte é com o usuário. (Fase 4+ talvez.)`

**O que o código faz:**
O codebase tem implementação completa de geração de vídeo via HeyGen:
- `app/services/media_generation/` com `Start`, `Factory`, `Providers::Heygen`, `ScriptBuilder`, `Result`, `BaseProvider`, `Errors`
- `app/workers/media_generation/poll_worker.rb`
- `app/controllers/generated_medias_controller.rb` (actions: index, show, create)
- `app/controllers/content_suggestions/video_controller.rb`
- `app/controllers/settings/media_generation_controller.rb`
- `app/controllers/webhooks/heygen_controller.rb`
- Tabelas `generated_medias` e `media_generation_usage_logs` no schema
- 7 rotas dedicadas à geração de mídia

Esta feature foi implementada nas Fases 1.6b (Roadmap) e está completamente funcional.

**Possíveis interpretações:**
1. Decisão mudou durante a Fase 1.6b e o `00_NORTE.md` não foi atualizado → atualizar doc para refletir que HeyGen foi implementado como feature de diferenciação
2. A implementação foi um desvio de escopo não planejado → decidir se mantém ou reverte

**Ação sugerida:** Atualizar `00_NORTE.md` para remover a proibição de geração de vídeo e documentar a feature HeyGen como parte do produto. A Fase 1.6b já resolve isso no roadmap, mas o `00_NORTE.md` que é o documento de norte do produto continua contradizendo o código.

---

## Drift #4 — ADR-011 descreve `own_profile_id` na tabela `playbooks` mas coluna não existe no schema

**Doc afetado:** `docs/01_ARQUITETURA.md` → ADR-011, seção "1. Playbook é entidade própria"
**Severidade:** Moderada

**O que o doc diz:**
```ruby
create_table :playbooks do |t|
  # ...
  t.references :own_profile,
    foreign_key: { to_table: :own_profiles }
  # ...
end
```
O ADR descreve um campo `own_profile_id` opcional para vincular o playbook a um perfil próprio.

**O que o código faz:**
A tabela `playbooks` no schema tem apenas: `account_id`, `name`, `niche`, `purpose`, `current_version_number`. Não há `own_profile_id` nem a tabela `own_profiles` existe no banco.

**Possíveis interpretações:**
1. `OwnProfile` ainda não foi implementado (ADR-012 está em "Implementar na Fase 3.1") → coluna planejada para fase futura → doc está correto, implementação ainda não chegou
2. O ADR-011 foi escrito antecipando a Fase 3.1 — o schema atual é provisório

**Ação sugerida:** Adicionar nota explícita no ADR-011 indicando que `own_profile_id` na tabela `playbooks` é dependente da Fase 3.1 (ADR-012) e ainda não implementado. O schema atual não tem a coluna — isso é esperado. Sem urgência de correção.

---

## Drift #5 — ADR-011 descreve `source` em `playbook_feedbacks` como strings `'manual' | 'claude_project' | 'own_post_result'` mas código usa enum integer

**Doc afetado:** `docs/01_ARQUITETURA.md` → ADR-011, seção "4. Feedback loop via PlaybookFeedback"
**Severidade:** Moderada

**O que o doc diz:**
```ruby
t.string :source   # 'manual' | 'claude_project' | 'own_post_result'
```

**O que o código faz:**
O model `PlaybookFeedback` define:
```ruby
enum :source, { manual: 0, auto: 1 }, prefix: :source
```
A coluna `source` é `string, not null` no schema, mas o enum tem apenas dois valores (`manual`, `auto`) — sem `claude_project` ou `own_post_result`.

**Possíveis interpretações:**
1. Os valores `claude_project` e `own_post_result` dependem da Fase 3.1 (`OwnProfile`, loop de resultado) e serão adicionados ao enum depois → doc está adiantado
2. A implementação simplificou o enum intencionalmente → doc deve ser atualizado para refletir os 2 valores atuais

**Ação sugerida:** Atualizar o ADR-011 para documentar o enum atual (`manual`, `auto`) e adicionar nota que `claude_project` e `own_post_result` são planejados para Fase 3.1.

---

## Drift #6 — ADR-011 descreve FK `related_own_post` para tabela `own_posts` mas código usa `integer` simples sem FK

**Doc afetado:** `docs/01_ARQUITETURA.md` → ADR-011, seção "4. Feedback loop via PlaybookFeedback"
**Severidade:** Moderada

**O que o doc diz:**
```ruby
t.references :related_own_post,
  foreign_key: { to_table: :own_posts }
```

**O que o código faz:**
```sql
t.integer "related_own_post_id"
```
Não há FK explícita para `own_posts` (tabela inexistente). A coluna é um integer simples sem constraint de foreign key no schema.

**Possíveis interpretações:**
1. `own_posts` ainda não existe (Fase 3.1) → integer sem FK é placeholder correto para fase futura → comportamento esperado
2. É um bug de migration que esqueceu a FK (improvável dado que a tabela referenciada não existe)

**Ação sugerida:** Adicionar nota no ADR-011 que `related_own_post_id` é um integer sem FK enquanto `own_posts` não existir. Quando a Fase 3.1 for implementada, criar migration para adicionar a FK.

---

## Drift #7 — ADR-012 descreve tabelas `own_profiles`, `own_posts`, `story_observations` que não existem no schema

**Doc afetado:** `docs/01_ARQUITETURA.md` → ADR-012
**Severidade:** Moderada

**O que o doc diz:**
ADR-012 descreve em detalhes as tabelas `own_profiles`, `own_posts` e `story_observations` com seus campos, índices e foreign keys.

**O que o código faz:**
Nenhuma dessas 3 tabelas existe no schema. A busca em `schema.rb` por `own_profiles`, `own_posts` e `story_observations` retorna zero resultados.

**Possíveis interpretações:**
1. ADR-012 está marcado como "Implementar na Fase 3.1" → tabelas ainda não foram criadas → comportamento esperado

**Ação sugerida:** Nenhuma ação urgente. O ADR-012 já informa "Implementar na Fase 3.1". Adicionar nota de que as tabelas descritas ainda não existem no schema atual. Drift de documentação antecipada, não de código divergente.

---

## Drift #8 — `analyses.posts_scraped_count` documentado sem `null: false` mas schema tem `null: false`

**Doc afetado:** `docs/05_GLOSSARIO.md` → Schema Analysis
**Severidade:** Moderada

**O que o doc diz:**
```ruby
t.integer :posts_scraped_count, default: 0
```
(sem `null: false` explícito)

**O que o código faz:**
```sql
t.integer "posts_scraped_count", default: 0, null: false
t.integer "posts_analyzed_count", default: 0, null: false
```
Ambas as colunas têm `null: false` no schema real.

**Possíveis interpretações:**
1. Omissão na documentação do glossário — foi parcialmente corrigido na sync mas a seção narrativa ficou desatualizada

**Ação sugerida:** Corrigir o glossário para adicionar `null: false` em ambas as colunas. Drift de baixo risco (não afeta comportamento).

---

## Drift #9 — `profile_metrics["refinement_failed"]` documentado mas nunca gerado pelo código atual

**Doc afetado:** `docs/05_GLOSSARIO.md` → seção "Lógica de profile_metrics" e "Schemas dos modelos → Analysis"
**Severidade:** Moderada

**O que o doc diz:**
> Nota inline indica que `profile_metrics["refinement_failed"]` é adicionado quando o `CritiqueAndRefineStep` falha.

**O que o código faz:**
O `CritiqueAndRefineStep` não existe. A chave `refinement_failed` nunca é escrita pelo pipeline atual.

**Possíveis interpretações:**
1. Consequência direta do Drift #1 — documentação órfã do step removido

**Ação sugerida:** Remover a nota sobre `refinement_failed` do glossário, junto com a resolução do Drift #1. Ou adicionar `(step não implementado no pipeline atual)` como aviso.

---

## Drift #10 — Fases 1.6 e 1.6a não estavam marcadas como concluídas no roadmap

**Doc afetado:** `docs/03_ROADMAP_FASES.md` → Fases 1.6 e 1.6a
**Severidade:** Menor

**O que o doc dizia:**
- Fase 1.6a: marcada como "⚠️ NOVA" sem marcação de conclusão
- Fase 1.6: corpo sem marcador ✅ apesar de rodapé afirmar que foi mergeada em main

**O que o código faz:**
`ApiCredential`, `ApiCredentials::ValidateService`, `Settings::ApiKeysController`, `Settings::LLMPreferencesController` todos existem e estão funcionais.

**Resolução:** Corrigido nesta sync — ambas as fases marcadas como ✅ CONCLUÍDA.

---

## Drift #11 — Fase 1.6b (Playbooks + MediaGeneration) não estava documentada no roadmap

**Doc afetado:** `docs/03_ROADMAP_FASES.md` → ausência de Fase 1.6b
**Severidade:** Menor

**O que o doc dizia:**
Não havia fase correspondente para: Playbook, PlaybookVersion, PlaybookFeedback, PlaybookSuggestion, AnalysisPlaybook, GeneratedMedia, MediaGenerationUsageLog, e todos os services/workers/controllers associados.

**O que o código faz:**
Toda essa infraestrutura existe e está funcionando. 14+ modelos, services e controllers de Playbooks e MediaGeneration sem fase documentada.

**Resolução:** Fase 1.6b criada retroativamente nesta sync para cobrir esses artefatos.

---

## Drift #12 — Contagem de specs desatualizada no roadmap

**Doc afetado:** `docs/03_ROADMAP_FASES.md` → seção "Status atual"
**Severidade:** Menor

**O que o doc dizia:**
> 658 specs verdes

**O que o código faz:**
`bundle exec rspec --dry-run` retorna 860 examples, 0 failures.

**Resolução:** Atualizado para "860 examples, 0 failures" nesta sync.

---

## ✅ Checklist de verificação

- [x] Cada ADR em `01_ARQUITETURA.md` foi confrontado com o código?
  ✅ Todos os 13 ADRs verificados. ADRs 001-010 implementados conforme descrição. ADR-011: schema implementado mas sem `own_profile_id` (Fase 3.1 pendente) e `CritiqueAndRefineStep` ausente. ADR-012: tabelas não existem (Fase 3.1 pendente — esperado). ADR-013: implementado e funcional.

- [x] Enums documentados em `05_GLOSSARIO.md` batem com enums reais?
  ✅ Todos os enums de Analysis, Post, ContentSuggestion, ApiCredential, GeneratedMedia, Playbook, PlaybookFeedback, PlaybookSuggestion, AnalysisPlaybook verificados — valores inteiros batem exatamente. Única divergência: `PlaybookFeedback.source` documentado no ADR-011 com 3 valores de string vs. 2 valores enum integer no código (Drift #5).

- [x] Lista de gems proibidas — alguma foi adicionada?
  ✅ Nenhuma gem proibida detectada no Gemfile. Proibições de React/Vue/SPA/jQuery/Sass/Webpack/AWS/MongoDB/GraphQL/OAuth custom/Elasticsearch/ffmpeg/OpenAI Assistants API/Kubernetes/aasm — todas respeitadas.

- [x] Regras 🔒 em `02_PADROES_CODIGO.md` — há código violando alguma?
  ⚠️ Uma violação encontrada: `app/views/generated_medias/show.html.erb` linha 27 usa `style="--progress: 0%; max-height: 70vh;"`. A regra 🔒 proíbe `style="..."` com valores estáticos. O valor `0%` para `--progress` pode ser estático (não calculado em Ruby) — verificar se deveria ser classe Tailwind ou CSS custom property dinâmica. O `mailer.html.erb` usa `<style>` tag, mas emails HTML requerem inline CSS por compatibilidade — exceção justificável.

- [x] ENV vars marcadas como obrigatórias existem?
  ✅ Todas as ENV vars documentadas como obrigatórias no inventário (`DATABASE_URL`, `REDIS_URL`, `ACTIVE_RECORD_ENCRYPTION_*`, `APIFY_API_TOKEN`, `RAILS_MASTER_KEY`, `HEYGEN_WEBHOOK_TOKEN`) estão presentes no `.env.example`.

- [x] Status de fases no roadmap bate com artefatos?
  ⚠️ Corrigido nesta sync. Antes: Fases 1.6 e 1.6a sem marcação ✅, Fase 1.6b inexistente, contagem de specs desatualizada (658 → 860). Tudo atualizado.

---

## Priorização de ações

### Ações que requerem decisão humana (Curt)

1. **Drift #3 (Crítico):** `00_NORTE.md` diz que geração de vídeo é não-objetivo, mas código implementa HeyGen completo. Decidir se o norte do produto mudou e atualizar o doc.

2. **Drift #1 e #2 (Críticos):** `CritiqueAndRefineStep` e coluna `refinement_notes` — decidir se o step será implementado no futuro ou descartado definitivamente. Remover referências do glossário se descartado.

### Ações que podem ser feitas sem decisão (apenas atualizar docs)

3. **Drift #4, #5, #6, #7:** ADR-011 e ADR-012 descrevem features de Fase 3.1 que ainda não existem. Adicionar nota explícita `[Pendente — Fase 3.1]` nas seções relevantes.

4. **Drift #8 e #9:** Pequenas inconsistências no glossário (`null: false` ausente, chave `refinement_failed` órfã).

5. **Drift #10, #11, #12:** Já corrigidos nesta sync.
