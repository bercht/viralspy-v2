# T3 Design — Real-time Progress via Turbo Stream + ActionCable

**Data:** 2026-04-20
**Fase:** 1.6 — T3
**Contexto:** T2 entregou fluxo de análise com meta refresh de 10s. T3 substitui por broadcasts reais via ActionCable + Turbo Stream.

---

## Objetivo

Substituir o polling via `<meta http-equiv="refresh">` por atualizações em tempo real. A cada mudança de `status` no model `Analysis`, todos os browsers com a tela aberta atualizam automaticamente — sem reload, sem polling.

Duas telas recebem updates:
1. **`analyses/show`** — substitui o bloco in_progress/failed/completed inteiro
2. **`competitors/show`** — item da análise na lista atualiza status badge sozinho

---

## Estado atual (pré-T3)

| Arquivo | Estado |
|---|---|
| `config/cable.yml` | dev usa `adapter: async` — broadcasts não cruzam containers |
| `app/models/analysis.rb` | sem callback de broadcast |
| `app/views/analyses/show.html.erb` | status badge no header + if/elsif/else inline, sem turbo_stream_from |
| `app/views/analyses/_in_progress.html.erb` | tem `<meta http-equiv="refresh" content="10">` |
| `app/views/analyses/_completed.html.erb` | usa instance vars (@profile_metrics, @posts_by_type, @suggestions) |
| `app/views/analyses/_failed.html.erb` | já usa locals (analysis, competitor) ✓ |
| `app/views/competitors/show.html.erb` | lista de análises inline, sem turbo_stream_from |
| `app/helpers/analyses_helper.rb` | não existe |
| `spec/rails_helper.rb` | sem `require "action_cable/testing/rspec"` |

---

## Arquitetura

### Por que Redis em dev é obrigatório

O `async` adapter é in-process. Com dois containers separados (`web` e `sidekiq`), cada um tem seu próprio pubsub. O worker atualiza status no container `sidekiq` → broadcast some no vácuo. O `web` container nunca recebe.

Redis resolve: pubsub externo compartilhado entre todos os containers.

**DB mapping (sem conflito):**
- `REDIS_URL=redis://redis:6379/0` → ActionCable dev usa `/0` (via `ENV.fetch("REDIS_URL")`)
- `SIDEKIQ_REDIS_URL=redis://redis:6379/1` → Sidekiq usa `/1`
- Sem sobreposição.

### Streams de broadcast

O model `Analysis` emite para dois streams distintos a cada mudança de status:

```
analysis_{id}                     → atualiza analyses/show (o body inteiro)
competitor_{competitor_id}_analyses → atualiza o item da lista em competitors/show
```

### Fonte única de broadcast

**Regra: o callback `after_update_commit` no model é a única fonte.** Nenhum step do pipeline, nenhum worker, chama broadcast diretamente.

---

## Componentes

### 1. `config/cable.yml`

```yaml
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://redis:6379/0" } %>
  channel_prefix: viralspy_dev

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>
  channel_prefix: viralspy_production
```

### 2. `Analysis` model — callback

```ruby
after_update_commit :broadcast_status_change, if: :saved_change_to_status?

private

def broadcast_status_change
  broadcast_replace_to(
    "analysis_#{id}",
    target: dom_id(self),
    partial: "analyses/analysis_body",
    locals: { analysis: self }
  )
  broadcast_replace_to(
    "competitor_#{competitor_id}_analyses",
    target: dom_id(self, :list_item),
    partial: "analyses/list_item",
    locals: { analysis: self, competitor: competitor }
  )
end
```

- `broadcast_replace_to` (não `update_to`) — substitui elemento inteiro, mais robusto
- `saved_change_to_status?` — dispara SOMENTE quando status muda; updates de outros campos (posts_scraped_count, profile_metrics) não geram broadcast

### 3. `AnalysesHelper#completed_locals`

```ruby
module AnalysesHelper
  def completed_locals(analysis)
    return {} unless analysis.completed?
    {
      profile_metrics: analysis.profile_metrics || {},
      posts_by_type: analysis.posts.where(selected_for_analysis: true).group_by(&:post_type),
      suggestions: analysis.content_suggestions.ordered
    }
  end
end
```

Usado em dois contextos:
- Controller (`show`) ao chamar `render`
- Partial `_analysis_body` ao renderizar `_completed` via broadcast

### 4. `AnalysesController#show`

```ruby
def show
  authorize @analysis
  load_completed_analysis_data if @analysis.completed?
end

def load_completed_analysis_data
  @completed_locals = completed_locals(@analysis)
end
```

No view: `render "completed", **@completed_locals` (ou equivalente passando locals).

### 5. Novo partial `_analysis_body.html.erb`

```erb
<%= tag.div id: dom_id(analysis) do %>
  <% if analysis.completed? %>
    <%= render "analyses/completed", **completed_locals(analysis) %>
  <% elsif analysis.failed? %>
    <%= render "analyses/failed", analysis: analysis, competitor: analysis.competitor %>
  <% else %>
    <%= render "analyses/in_progress", analysis: analysis %>
  <% end %>
<% end %>
```

O `id: dom_id(analysis)` gera `analysis_123` — target exato do `broadcast_replace_to`.

### 6. `_completed.html.erb` — converter instance vars para locals

- `@profile_metrics` → `profile_metrics`
- `@posts_by_type` → `posts_by_type`
- `@suggestions` → `suggestions`

Note: `@insights` estava no spec mas não existe no partial atual — ignorar.

### 7. `analyses/show.html.erb`

```erb
<%= turbo_stream_from "analysis_#{@analysis.id}" %>

<div class="mx-auto max-w-5xl">
  <header class="mb-8">
    <%# ... breadcrumb + title + datas ... %>
    <%# Status badge REMOVIDO do header — fica dentro dos sub-partials %>
  </header>

  <%= render "analyses/analysis_body", analysis: @analysis %>
</div>
```

**Decisão: status badge removido do header.** O badge fica dentro de cada sub-partial. Manter no header exigiria um terceiro stream de broadcast e um terceiro target. Custo não justificado.

### 8. `_in_progress.html.erb` — remover meta refresh

- Remover `<% content_for :head do %><meta http-equiv="refresh" content="10"><% end %>`
- Remover botão "Atualizar página"
- Atualizar texto do `<p>` pra refletir comportamento real-time

### 9. `competitors/show.html.erb`

```erb
<%= turbo_stream_from "competitor_#{@competitor.id}_analyses" %>

<%# ... header ... %>

<% @analyses.each do |analysis| %>
  <%= render "analyses/list_item", analysis: analysis, competitor: @competitor %>
<% end %>
```

### 10. Novo partial `_list_item.html.erb`

```erb
<%= tag.div id: dom_id(analysis, :list_item) do %>
  <li class="px-6 py-4">
    <%= link_to competitor_analysis_path(competitor, analysis), class: "..." do %>
      <%# ... datas + posts_scraped_count ... %>
      <%= render "shared/status_badge", status: analysis.status %>
    <% end %>
  </li>
<% end %>
```

`dom_id(analysis, :list_item)` gera `list_item_analysis_123` — target exato do segundo `broadcast_replace_to`.

---

## Testes

### `spec/rails_helper.rb`

Adicionar: `require "action_cable/testing/rspec"`

### `spec/models/analysis_spec.rb` — 4 novos casos

1. Broadcast emitido para `analysis_{id}` ao mudar status
2. Broadcast emitido para `competitor_{id}_analyses` ao mudar status
3. Sem broadcast quando campo não-status é atualizado (`posts_scraped_count`)
4. Sem broadcast quando status não muda (update com mesmo valor)

---

## Critérios de aceite

- [ ] `config/cable.yml` dev usa `adapter: redis`
- [ ] `Analysis` tem `after_update_commit :broadcast_status_change, if: :saved_change_to_status?`
- [ ] `_analysis_body` partial com `dom_id(analysis)` como wrapper
- [ ] `_list_item` partial com `dom_id(analysis, :list_item)` como wrapper
- [ ] `analyses/show` tem `turbo_stream_from` e usa `_analysis_body`
- [ ] `competitors/show` tem `turbo_stream_from` e usa `_list_item`
- [ ] `<meta http-equiv="refresh">` removido de `_in_progress`
- [ ] `_completed` convertido de instance vars para locals
- [ ] `AnalysesHelper#completed_locals` criado
- [ ] 4 specs verdes + zero regressão
- [ ] Smoke test: `analysis.update!(status: :scraping)` no console → browser atualiza em <1s
- [ ] Rubocop e ERB Lint verdes

---

## Commits planejados

**Commit 1 — infra + model:**
```
feat(analyses): broadcast status changes via Turbo Stream

- Switch cable.yml dev to Redis adapter (cross-container web↔sidekiq)
- after_update_commit callback on Analysis, guarded by saved_change_to_status?
- Broadcasts to analysis_{id} (show) and competitor_{id}_analyses (list)
- Extract completed_locals to AnalysesHelper; convert _completed to locals
- Specs: 4 broadcast cases + action_cable/testing/rspec require

Part of Fase 1.6 (T3).
```

**Commit 2 — views:**
```
feat(analyses): wire turbo_stream_from + remove meta refresh

- analyses/show subscribes to analysis_{id} stream via _analysis_body wrapper
- competitors/show subscribes to competitor_{id}_analyses via _list_item wrapper
- _in_progress: remove meta refresh, update copy for real-time behavior
- Status badge removed from analyses/show header (inside partials now)

Part of Fase 1.6 (T3).
```
