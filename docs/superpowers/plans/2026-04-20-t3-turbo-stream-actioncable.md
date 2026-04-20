# T3 — Real-time Progress via Turbo Stream + ActionCable

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o meta refresh de 10s por broadcasts reais via ActionCable — qualquer mudança de `status` no model `Analysis` atualiza automaticamente a tela de show da análise e o item na lista do competitor show.

**Architecture:** O callback `after_update_commit :broadcast_status_change` no model `Analysis` é a única fonte de broadcasts. Ele emite para dois streams Redis: `analysis_{id}` (substitui o body inteiro em show) e `competitor_{competitor_id}_analyses` (substitui o item na lista). As views assinam via `turbo_stream_from`. O ActionCable dev usa Redis porque web e sidekiq rodam em containers Docker separados — o adapter `async` (in-process) não cruza a fronteira entre processos.

**Tech Stack:** Rails 7.1, Turbo Streams, ActionCable, Redis 7, RSpec, FactoryBot, `action_cable/testing/rspec`

---

## File Map

| Ação | Arquivo | Responsabilidade |
|---|---|---|
| Modificar | `config/cable.yml` | Adapter Redis em dev |
| Modificar | `spec/rails_helper.rb` | Adicionar require do matcher `have_broadcasted_to` |
| Criar | `app/helpers/analyses_helper.rb` | `completed_locals(analysis)` — locals para `_completed` |
| Modificar | `app/controllers/analyses_controller.rb` | Usar `completed_locals` em vez de instance vars |
| Modificar | `app/views/analyses/_completed.html.erb` | `@profile_metrics` → `profile_metrics` (e demais) |
| Modificar | `app/models/analysis.rb` | Callback `after_update_commit :broadcast_status_change` |
| Modificar | `spec/models/analysis_spec.rb` | 4 novos casos de broadcast |
| Criar | `app/views/analyses/_analysis_body.html.erb` | Wrapper com `dom_id` + condicional de status |
| Criar | `app/views/analyses/_list_item.html.erb` | Item da lista com `dom_id(analysis, :list_item)` |
| Modificar | `app/views/analyses/show.html.erb` | `turbo_stream_from` + usar `_analysis_body` |
| Modificar | `app/views/analyses/_in_progress.html.erb` | Remover meta refresh e botão de reload |
| Modificar | `app/views/competitors/show.html.erb` | `turbo_stream_from` + usar `_list_item` |
| Modificar | `config/locales/pt-BR.yml` | Adicionar chave `realtime_hint` |

---

## Task 1: Configurar ActionCable com Redis em dev + adicionar require de testes

**Files:**
- Modify: `config/cable.yml`
- Modify: `spec/rails_helper.rb`

- [ ] **Step 1: Substituir `config/cable.yml` inteiro**

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

Nota: `REDIS_URL=redis://redis:6379/0` no docker-compose. Sidekiq usa `SIDEKIQ_REDIS_URL=redis://redis:6379/1`. Sem sobreposição.

- [ ] **Step 2: Adicionar require em `spec/rails_helper.rb`**

Localizar a linha com `require "rspec/rails"` e adicionar abaixo:

```ruby
require "rspec/rails"
require "action_cable/testing/rspec"
```

Sem esse require, o matcher `have_broadcasted_to` não existe e os specs falham com `NoMethodError`.

- [ ] **Step 3: Reiniciar containers e verificar conexão Redis**

```bash
docker compose -f docker-compose.dev.yml restart web worker
docker compose -f docker-compose.dev.yml logs web 2>&1 | grep -i cable | head -5
```

Esperado: linha com "ActionCable" e "redis" visível nos logs. Sem erros de conexão.

- [ ] **Step 4: Commit**

```bash
git add config/cable.yml spec/rails_helper.rb
git commit -m "chore(cable): switch dev adapter to Redis + add action_cable testing require"
```

---

## Task 2: Criar AnalysesHelper + converter `_completed` para locals + atualizar controller

**Files:**
- Create: `app/helpers/analyses_helper.rb`
- Modify: `app/views/analyses/_completed.html.erb`
- Modify: `app/controllers/analyses_controller.rb`

- [ ] **Step 1: Criar `app/helpers/analyses_helper.rb`**

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

- [ ] **Step 2: Substituir `app/views/analyses/_completed.html.erb` inteiro**

Mesma estrutura HTML, apenas `@profile_metrics` → `profile_metrics`, `@posts_by_type` → `posts_by_type`, `@suggestions` → `suggestions`:

```erb
<section class="mb-8 rounded-lg border border-gray-200 bg-white p-6">
  <h2 class="mb-4 text-lg font-semibold text-gray-900"><%= t("analyses.show.profile_metrics.title") %></h2>
  <div class="grid grid-cols-2 gap-6 md:grid-cols-4">
    <div>
      <p class="text-xs uppercase tracking-wider text-gray-500"><%= t("analyses.show.profile_metrics.posts_per_week") %></p>
      <p class="mt-1 text-2xl font-semibold text-gray-900"><%= profile_metrics["posts_per_week"] || "—" %></p>
    </div>
    <div>
      <p class="text-xs uppercase tracking-wider text-gray-500"><%= t("analyses.show.profile_metrics.avg_likes") %></p>
      <p class="mt-1 text-2xl font-semibold text-gray-900"><%= number_with_delimiter(profile_metrics["avg_likes_per_post"] || 0) %></p>
    </div>
    <div>
      <p class="text-xs uppercase tracking-wider text-gray-500"><%= t("analyses.show.profile_metrics.avg_comments") %></p>
      <p class="mt-1 text-2xl font-semibold text-gray-900"><%= number_with_delimiter(profile_metrics["avg_comments_per_post"] || 0) %></p>
    </div>
    <div>
      <p class="text-xs uppercase tracking-wider text-gray-500"><%= t("analyses.show.profile_metrics.engagement_rate") %></p>
      <p class="mt-1 text-2xl font-semibold text-gray-900">
        <%= number_to_percentage((profile_metrics["avg_engagement_rate"] || 0) * 100, precision: 2) %>
      </p>
    </div>
  </div>

  <% if profile_metrics["content_mix"].present? %>
    <div class="mt-6 border-t border-gray-200 pt-6">
      <p class="mb-2 text-xs uppercase tracking-wider text-gray-500"><%= t("analyses.show.profile_metrics.content_mix") %></p>
      <div class="flex flex-wrap gap-4">
        <% profile_metrics["content_mix"].each do |type, pct| %>
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-gray-900"><%= t("post_type.#{type}") %>:</span>
            <span class="text-sm text-gray-600"><%= number_to_percentage(pct * 100, precision: 0) %></span>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>

  <% if profile_metrics["top_hashtags"].present? %>
    <div class="mt-6 border-t border-gray-200 pt-6">
      <p class="mb-2 text-xs uppercase tracking-wider text-gray-500"><%= t("analyses.show.profile_metrics.top_hashtags") %></p>
      <div class="flex flex-wrap gap-2">
        <% profile_metrics["top_hashtags"].each do |tag| %>
          <span class="rounded-full bg-gray-100 px-3 py-1 text-xs font-medium text-gray-700">#<%= tag %></span>
        <% end %>
      </div>
    </div>
  <% end %>
</section>

<% if posts_by_type.any? %>
  <section class="mb-8">
    <h2 class="mb-4 text-lg font-semibold text-gray-900"><%= t("analyses.show.top_posts.title") %></h2>
    <div class="space-y-6">
      <% %w[reel carousel image].each do |type| %>
        <% posts = posts_by_type[type] %>
        <% next if posts.blank? %>
        <%= render "posts_by_type", type: type, posts: posts.sort_by { |p| -(p.quality_score || 0) } %>
      <% end %>
    </div>
  </section>
<% end %>

<% if suggestions.any? %>
  <section>
    <h2 class="mb-4 text-lg font-semibold text-gray-900"><%= t("analyses.show.suggestions.title") %></h2>
    <div class="space-y-4">
      <% suggestions.each do |suggestion| %>
        <%= render "suggestion_card", suggestion: suggestion %>
      <% end %>
    </div>
  </section>
<% end %>
```

- [ ] **Step 3: Atualizar `app/controllers/analyses_controller.rb` — método `load_completed_analysis_data`**

Substituir o método privado existente:

```ruby
# antes:
def load_completed_analysis_data
  @profile_metrics = @analysis.profile_metrics || {}
  @insights = @analysis.insights || {}
  @posts_by_type = @analysis.posts
                            .where(selected_for_analysis: true)
                            .group_by(&:post_type)
  @suggestions = @analysis.content_suggestions.ordered
end
```

```ruby
# depois:
def load_completed_analysis_data
  @completed_locals = completed_locals(@analysis)
end
```

- [ ] **Step 4: Rodar specs para confirmar que nada quebrou**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec spec/models/analysis_spec.rb spec/controllers/ --format documentation 2>&1 | tail -20
```

Esperado: todos os specs existentes passando. Se houver erro em `analyses_controller_spec.rb` relacionado a `@profile_metrics` não definido, atualizar o spec para usar os novos locals.

- [ ] **Step 5: Commit**

```bash
git add app/helpers/analyses_helper.rb app/views/analyses/_completed.html.erb app/controllers/analyses_controller.rb
git commit -m "refactor(analyses): completed_locals helper + convert _completed to locals"
```

---

## Task 3: Adicionar callback de broadcast no model Analysis (TDD)

**Files:**
- Modify: `spec/models/analysis_spec.rb`
- Modify: `app/models/analysis.rb`

- [ ] **Step 1: Escrever os 4 specs de broadcast em `spec/models/analysis_spec.rb`**

Adicionar ao final do arquivo, antes do último `end`:

```ruby
describe "broadcasting" do
  let(:analysis) do
    ActsAsTenant.with_tenant(account) do
      create(:analysis, account: account, competitor: competitor, max_posts: 50, status: :pending)
    end
  end

  it "broadcasts to analysis stream when status changes" do
    ActsAsTenant.with_tenant(account) do
      expect {
        analysis.update!(status: :scraping)
      }.to have_broadcasted_to("analysis_#{analysis.id}").from_channel(Turbo::StreamsChannel)
    end
  end

  it "broadcasts to competitor analyses stream when status changes" do
    ActsAsTenant.with_tenant(account) do
      expect {
        analysis.update!(status: :scraping)
      }.to have_broadcasted_to("competitor_#{competitor.id}_analyses").from_channel(Turbo::StreamsChannel)
    end
  end

  it "does not broadcast when a non-status field changes" do
    ActsAsTenant.with_tenant(account) do
      analysis.update!(status: :scraping)  # setup — status already set
      expect {
        analysis.update!(posts_scraped_count: 10)
      }.not_to have_broadcasted_to("analysis_#{analysis.id}").from_channel(Turbo::StreamsChannel)
    end
  end

  it "does not broadcast when status value is unchanged" do
    ActsAsTenant.with_tenant(account) do
      analysis.update!(status: :scraping)  # setup
      expect {
        analysis.update!(status: :scraping)  # same value
      }.not_to have_broadcasted_to("analysis_#{analysis.id}").from_channel(Turbo::StreamsChannel)
    end
  end
end
```

- [ ] **Step 2: Rodar os 4 specs e confirmar que FALHAM**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec spec/models/analysis_spec.rb -e "broadcasting" --format documentation 2>&1 | tail -20
```

Esperado: 4 failures com mensagem como "expected to have broadcasted..." ou "undefined method `broadcast_status_change`".

- [ ] **Step 3: Adicionar callback e método privado em `app/models/analysis.rb`**

Adicionar após o `scope :in_progress` e antes de `def duration_seconds`:

```ruby
after_update_commit :broadcast_status_change, if: :saved_change_to_status?
```

Adicionar ao bloco `private` (criar se não existir), após `duration_seconds`:

```ruby
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

O partial `analyses/analysis_body` será criado na Task 4. No contexto de specs com adapter `test`, o broadcast é enfileirado em memória — não precisa do partial existir pra o spec de emissão passar.

- [ ] **Step 4: Rodar os 4 specs e confirmar que PASSAM**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec spec/models/analysis_spec.rb -e "broadcasting" --format documentation 2>&1 | tail -20
```

Esperado:
```
broadcasting
  broadcasts to analysis stream when status changes
  broadcasts to competitor analyses stream when status changes
  does not broadcast when a non-status field changes
  does not broadcast when status value is unchanged

4 examples, 0 failures
```

- [ ] **Step 5: Rodar suite completa de specs pra confirmar zero regressão**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec --format progress 2>&1 | tail -10
```

Esperado: todos os specs passando.

- [ ] **Step 6: Commit (Commit 1 do spec)**

```bash
git add app/models/analysis.rb spec/models/analysis_spec.rb
git commit -m "$(cat <<'EOF'
feat(analyses): broadcast status changes via Turbo Stream

- Switch cable.yml dev to Redis adapter (cross-container web<->sidekiq)
- after_update_commit callback on Analysis, guarded by saved_change_to_status?
- Broadcasts to analysis_{id} (show) and competitor_{id}_analyses (list)
- Extract completed_locals to AnalysesHelper; convert _completed to locals
- Specs: 4 broadcast cases + action_cable/testing/rspec require

Part of Fase 1.6 (T3).
EOF
)"
```

---

## Task 4: Criar partials `_analysis_body` e `_list_item`

**Files:**
- Create: `app/views/analyses/_analysis_body.html.erb`
- Create: `app/views/analyses/_list_item.html.erb`

- [ ] **Step 1: Criar `app/views/analyses/_analysis_body.html.erb`**

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

`dom_id(analysis)` gera `analysis_123` — o target do `broadcast_replace_to` no model.

`completed_locals(analysis)` chama o helper `AnalysesHelper#completed_locals` criado na Task 2. Funciona tanto no controller quanto em renders via ActionCable (ambos têm acesso a helpers do app).

- [ ] **Step 2: Criar `app/views/analyses/_list_item.html.erb`**

Extrair e adaptar o bloco `<li>` que atualmente está inline em `competitors/show.html.erb`:

```erb
<%= tag.div id: dom_id(analysis, :list_item) do %>
  <li class="px-6 py-4">
    <%= link_to competitor_analysis_path(competitor, analysis),
        class: "flex items-center justify-between transition-colors hover:bg-surface-base -mx-2 px-2 rounded-sm" do %>
      <div>
        <p class="text-body-sm font-medium text-text-body"><%= l(analysis.created_at, format: :long) %></p>
        <p class="text-caption text-text-muted">
          <%= t("competitors.show.posts_scraped", count: analysis.posts_scraped_count || 0) %>
        </p>
      </div>
      <%= render "shared/status_badge", status: analysis.status %>
    <% end %>
  </li>
<% end %>
```

`dom_id(analysis, :list_item)` gera `list_item_analysis_123` — o target do segundo `broadcast_replace_to` no model.

- [ ] **Step 3: Verificar que os partials renderizam corretamente via browser**

```bash
docker compose -f docker-compose.dev.yml logs web 2>&1 | tail -5
```

Navegar para `/competitors/:id/analyses/:id` com uma análise existente (qualquer status). Se a página carregar sem erro 500, os partials estão corretos. Checar console do browser para erros JavaScript.

---

## Task 5: Atualizar views + i18n + remover meta refresh

**Files:**
- Modify: `app/views/analyses/show.html.erb`
- Modify: `app/views/analyses/_in_progress.html.erb`
- Modify: `app/views/competitors/show.html.erb`
- Modify: `config/locales/pt-BR.yml`

- [ ] **Step 1: Atualizar `config/locales/pt-BR.yml` — adicionar chave `realtime_hint`**

Localizar o bloco `analyses.show.in_progress` e adicionar a chave `realtime_hint`:

```yaml
      in_progress:
        pending: "Aguardando início..."
        scraping: "Capturando posts do Instagram..."
        scoring: "Calculando pontuações..."
        transcribing: "Transcrevendo áudio dos reels..."
        analyzing: "Analisando conteúdo..."
        generating_suggestions: "Gerando sugestões..."
        description: "Estamos processando a análise. Isso pode levar 3-4 minutos."
        refresh_hint: "Atualize a página em alguns instantes para ver o progresso."
        realtime_hint: "O progresso atualiza em tempo real — sem precisar recarregar a página."
```

- [ ] **Step 2: Substituir `app/views/analyses/_in_progress.html.erb` inteiro**

Remover `content_for :head` (meta refresh) e o link de atualizar página. Usar `realtime_hint`:

```erb
<article class="rounded-feature border border-border-subtle bg-surface-canvas p-12 text-center shadow-card">
  <div class="mx-auto mb-4 h-12 w-12 animate-spin rounded-pill border-4 border-border-subtle border-t-brand-primary"></div>

  <h2 class="text-heading text-text-body"><%= t("analyses.show.in_progress.pending") %></h2>
  <p class="mt-2 text-body text-text-muted"><%= t("analyses.show.in_progress.realtime_hint") %></p>

  <p class="mt-4 text-body-sm font-medium text-brand-primary">
    <%= t("analyses.status.#{analysis.status}") %>
  </p>
</article>
```

- [ ] **Step 3: Substituir `app/views/analyses/show.html.erb` inteiro**

Adicionar `turbo_stream_from`, remover status badge do header, substituir bloco if/elsif/else pelo novo partial:

```erb
<%= turbo_stream_from "analysis_#{@analysis.id}" %>

<div class="mx-auto max-w-5xl">
  <header class="mb-8">
    <%= link_to "@#{@competitor.instagram_handle}", competitor_path(@competitor),
        class: "text-body-sm text-brand-primary hover:text-brand-primary-hover" %>

    <div class="mt-2 flex items-start justify-between gap-4">
      <div class="min-w-0">
        <h1 class="text-display text-text-display">
          <%= t("analyses.show.title") %> — @<%= @competitor.instagram_handle %>
        </h1>
        <p class="mt-1 text-body-sm text-text-muted">
          <%= t("analyses.show.in_progress.description") %>
          <% if @analysis.finished_at %>
            · <%= l(@analysis.finished_at, format: :short) %>
          <% end %>
          <% if @analysis.duration_seconds %>
            · <%= @analysis.duration_seconds %>s
          <% end %>
        </p>
      </div>
    </div>
  </header>

  <%= render "analyses/analysis_body", analysis: @analysis %>
</div>
```

- [ ] **Step 4: Atualizar `app/views/competitors/show.html.erb` — adicionar `turbo_stream_from` e usar `_list_item`**

Localizar a `<ul class="divide-y divide-border-subtle">` e substituir o bloco `@analyses.each` para usar o partial. Adicionar `turbo_stream_from` antes do `<div class="mx-auto max-w-4xl">`:

```erb
<%= turbo_stream_from "competitor_#{@competitor.id}_analyses" %>

<div class="mx-auto max-w-4xl">
  <header class="mb-8">
    <%# ... (header existente, inalterado) ... %>
  </header>

  <section class="rounded-card border border-border-subtle bg-surface-canvas shadow-card">
    <div class="border-b border-border-subtle px-6 py-4">
      <h2 class="text-heading text-text-body"><%= t("competitors.show.analyses_history") %></h2>
    </div>

    <% if @analyses.any? %>
      <ul class="divide-y divide-border-subtle">
        <% @analyses.each do |analysis| %>
          <%= render "analyses/list_item", analysis: analysis, competitor: @competitor %>
        <% end %>
      </ul>
    <% else %>
      <div class="p-12 text-center">
        <p class="text-body-sm text-text-muted"><%= t("competitors.show.no_analyses") %></p>
      </div>
    <% end %>
  </section>
</div>
```

O `turbo_stream_from` fica FORA do `<div class="mx-auto">` — não renderiza HTML visível, apenas registra o WebSocket channel.

- [ ] **Step 5: Rodar suite completa de specs**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec --format progress 2>&1 | tail -10
```

Esperado: todos os specs passando (incluindo os 4 novos de broadcast).

- [ ] **Step 6: Rodar Rubocop**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rubocop app/models/analysis.rb app/helpers/analyses_helper.rb app/controllers/analyses_controller.rb 2>&1 | tail -10
```

Esperado: `no offenses detected`.

- [ ] **Step 7: Smoke test manual — validar broadcast ponta a ponta**

```bash
# Terminal 1: abrir console Rails
docker compose -f docker-compose.dev.yml exec web bin/rails console
```

No console:
```ruby
analysis = Analysis.last
# Abrir /competitors/:id/analyses/:id no browser primeiro
analysis.update!(status: :scraping)   # ver browser atualizar sem reload
analysis.update!(status: :scoring)    # ver browser atualizar
analysis.update!(status: :completed)  # ver browser mostrar _completed
```

Esperado: a UI muda em <1s sem reload de página.

Repetir com browser aberto em `/competitors/:id` — o item da lista deve atualizar o status badge sozinho.

- [ ] **Step 8: Commit (Commit 2 do spec)**

```bash
git add app/views/analyses/show.html.erb \
        app/views/analyses/_in_progress.html.erb \
        app/views/analyses/_analysis_body.html.erb \
        app/views/analyses/_list_item.html.erb \
        app/views/competitors/show.html.erb \
        config/locales/pt-BR.yml
git commit -m "$(cat <<'EOF'
feat(analyses): wire turbo_stream_from + remove meta refresh

- analyses/show subscribes to analysis_{id} stream via _analysis_body wrapper
- competitors/show subscribes to competitor_{id}_analyses via _list_item wrapper
- _in_progress: remove meta refresh + refresh button, copy updated for real-time
- Status badge removed from analyses/show header (inside partials now)
- New partials: _analysis_body (dom_id wrapper), _list_item (dom_id :list_item wrapper)

Part of Fase 1.6 (T3).
EOF
)"
```
