# LLM Prompts Index

Índice de todos os prompts em `app/prompts/`. Gerado automaticamente — não edite à mão.

6 namespaces, 10 arquivos (4 namespaces com system + user, 2 com apenas user).

---

## analyze_reels/system (system)

**Path:** `app/prompts/analyze_reels/system.erb`
**Usado por:** `Analyses::AnalyzeStep` (type: `:reel`, use_case: `"reel_analysis"`)
**Propósito:** Instrui o LLM a ser especialista em análise de Reels para o mercado imobiliário brasileiro, extraindo hooks, estruturas narrativas, CTAs e temas recorrentes. Exige resposta em JSON válido com schema fixo: `{ hooks, structures, ctas, themes, observations }`.
**Locals esperados:** (nenhum — conteúdo estático)

---

## analyze_reels/user (user)

**Path:** `app/prompts/analyze_reels/user.erb`
**Usado por:** `Analyses::AnalyzeStep` (type: `:reel`)
**Propósito:** Monta a mensagem com dados dos Reels selecionados (caption, transcript, engajamento, hashtags, tempo) para análise.
**Locals esperados:**
- `posts` — Array de objetos Post (com `caption`, `transcript`, `likes_count`, `comments_count`, `video_view_count`, `hashtags`, `posted_at`)
- `handle` — String (Instagram handle do competitor)
- `followers` — Integer (seguidores)
- `profile_metrics` — Hash (contém `posts_per_week`, `avg_engagement_rate`, `content_mix`)

---

## analyze_carousels/system (system)

**Path:** `app/prompts/analyze_carousels/system.erb`
**Usado por:** `Analyses::AnalyzeStep` (type: `:carousel`, use_case: `"carousel_analysis"`)
**Propósito:** Instrui o LLM a analisar carrosséis, extraindo estruturas de slides (gancho/desenvolvimento/CTA), tipos de conteúdo (educacional, comparativo, checklist) e temas. JSON com schema: `{ structures, content_types, themes, observations }`.
**Locals esperados:** (nenhum — conteúdo estático)

---

## analyze_carousels/user (user)

**Path:** `app/prompts/analyze_carousels/user.erb`
**Usado por:** `Analyses::AnalyzeStep` (type: `:carousel`)
**Propósito:** Monta a mensagem com dados dos carrosséis (caption, engajamento, hashtags, tempo) para análise.
**Locals esperados:**
- `posts` — Array de objetos Post (com `caption`, `likes_count`, `comments_count`, `hashtags`, `posted_at`)
- `handle` — String
- `followers` — Integer
- `profile_metrics` — Hash (contém `posts_per_week`, `avg_engagement_rate`)

---

## analyze_images/system (system)

**Path:** `app/prompts/analyze_images/system.erb`
**Usado por:** `Analyses::AnalyzeStep` (type: `:image`, use_case: `"image_analysis"`)
**Propósito:** Instrui o LLM a analisar imagens estáticas, identificando estilos de caption (informativo/emocional/comercial), elementos visuais comentados e temas. JSON com schema: `{ caption_styles, visual_elements, themes, observations }`.
**Locals esperados:** (nenhum — conteúdo estático)

---

## analyze_images/user (user)

**Path:** `app/prompts/analyze_images/user.erb`
**Usado por:** `Analyses::AnalyzeStep` (type: `:image`)
**Propósito:** Monta a mensagem com dados das imagens (caption, engajamento, hashtags, tempo) para análise.
**Locals esperados:**
- `posts` — Array de objetos Post (com `caption`, `likes_count`, `comments_count`, `hashtags`, `posted_at`)
- `handle` — String
- `followers` — Integer

---

## generate_suggestions/system (system)

**Path:** `app/prompts/generate_suggestions/system.erb`
**Usado por:** `Analyses::GenerateSuggestionsStep` (use_case: `"content_suggestions"`)
**Propósito:** Instrui o LLM a gerar N sugestões originais de posts para o usuário (não cópias do competitor), com mix de tipos especificado. JSON com schema: `{ suggestions: [{ position, content_type, hook, caption_draft, format_details, suggested_hashtags, rationale }] }`. `format_details` varia por tipo.
**Locals esperados:**
- `target_count` — Integer (constante: 5)
- `mix_label` — String (ex: "2 reels + 2 carousels + 1 image")

---

## generate_suggestions/user (user)

**Path:** `app/prompts/generate_suggestions/user.erb`
**Usado por:** `Analyses::GenerateSuggestionsStep`
**Propósito:** Fornece dados do perfil analisado (handle, seguidores, profile_metrics, insights) e solicita as N sugestões com o mix especificado.
**Locals esperados:**
- `handle` — String
- `followers` — Integer
- `profile_metrics` — Hash (JSON serializado)
- `insights` — Hash (JSON serializado, contém keys reels/carousels/images)
- `target_count` — Integer
- `mix_label` — String

---

## playbook_suggestions/user (user)

**Path:** `app/prompts/playbook_suggestions/user.erb`
**Usado por:** `Playbooks::GenerateSuggestionsService` (use_case: `"playbook_suggestions"`)
**Propósito:** Prompt único (sem system separado) que instrui e fornece dados para gerar sugestões de conteúdo baseadas no playbook acumulado. Inclui instruções condicionais por `content_type` (story/reel/carousel/image). JSON com schema: `{ suggestions: [{ hook, caption_draft, format_details, suggested_hashtags, rationale }] }`.
**Locals esperados:**
- `playbook_name` — String
- `playbook_niche` — String
- `playbook_purpose` — String
- `current_content` — String (markdown do playbook atual)
- `content_type` — String (`"reel"`, `"carousel"`, `"image"`, `"story"`)
- `quantity` — Integer
- `previous_suggestions` — Array de Hashes `{ hook:, rationale: }` (pode ser vazio). Histórico das últimas 20 sugestões do mesmo `content_type`, excluindo `discarded`, ordenadas por `created_at DESC`.

---

## update_playbook/user (user)

**Path:** `app/prompts/update_playbook/user.erb`
**Usado por:** `Analyses::UpdatePlaybookStep` (use_case: `"update_playbook"`)
**Propósito:** Prompt único que instrui e fornece dados para atualizar o playbook com novos insights e feedbacks pendentes. Exige resposta em markdown com separador `---DIFF_SUMMARY---` seguido de resumo de mudanças em 1-3 frases.
**Locals esperados:**
- `playbook_name` — String
- `playbook_niche` — String
- `playbook_purpose` — String
- `current_version_number` — Integer
- `current_content` — String (markdown completo da versão atual)
- `competitor_handle` — String
- `pending_feedbacks` — Array de objetos PlaybookFeedback (acessados via `.content`)
- `profile_metrics` — Hash (JSON pretty-printed)
- `insights` — Hash (JSON pretty-printed)
