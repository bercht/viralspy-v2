# Signup View Redesign — PlayStation Design System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refatorar `app/views/devise/registrations/new.html.erb` aplicando o design system PlayStation Inspired (two-panel layout, Outfit font, PlayStation Blue `#0070cc`, Console Black left / Paper White right), mantendo comportamento idêntico ao atual.

**Architecture:** Quatro artefatos independentes modificados em sequência — controller (layout), locales (copy), Stimulus controller (password toggle), view (HTML). Zero mudança de comportamento: os mesmos params chegam ao mesmo controller pelo mesmo path.

**Tech Stack:** Ruby on Rails 7.1, Devise, Tailwind CSS (utility classes only), Hotwire Stimulus, ERB

---

## File Map

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `app/controllers/users/registrations_controller.rb` | Modificar | Declarar `layout "marketing"` |
| `config/locales/pt-BR.yml` | Modificar | Labels neutros, sem referência a nicho específico |
| `app/javascript/controllers/password_toggle_controller.js` | Criar | Toggle tipo/visibilidade dos campos de senha |
| `app/views/devise/registrations/new.html.erb` | Modificar | Layout two-panel com design system completo |

**Nota sobre registro do Stimulus controller:** O projeto usa `eagerLoadControllersFrom("controllers", application)` em `index.js` — qualquer arquivo `*_controller.js` criado em `app/javascript/controllers/` é auto-descoberto. Não é necessário editar `index.js`.

---

## Task 1: Declarar layout "marketing" no RegistrationsController

**Files:**
- Modify: `app/controllers/users/registrations_controller.rb`

- [ ] **Step 1: Verificar baseline dos specs**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec spec/requests/users/registrations_spec.rb --format documentation
```

Esperado: todos os exemplos passando. Se algum falhar antes das mudanças, parar e investigar.

- [ ] **Step 2: Adicionar `layout "marketing"` ao controller**

Abrir `app/controllers/users/registrations_controller.rb`. O arquivo começa com:

```ruby
# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :authenticate_user!, only: [ :new, :create ]
  skip_before_action :set_current_tenant, only: [ :new, :create ]
```

Adicionar `layout "marketing"` logo após a linha `class`:

```ruby
# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  layout "marketing"

  skip_before_action :authenticate_user!, only: [ :new, :create ]
  skip_before_action :set_current_tenant, only: [ :new, :create ]
```

- [ ] **Step 3: Verificar que os specs ainda passam**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec spec/requests/users/registrations_spec.rb --format documentation
```

Esperado: mesmos resultados do Step 1. O layout não afeta specs de request (não renderizam layout completo por padrão).

- [ ] **Step 4: Commit**

```bash
git add app/controllers/users/registrations_controller.rb
git commit -m "feat(auth): declare marketing layout in RegistrationsController"
```

---

## Task 2: Atualizar locales — copy neutra e sem referências de nicho

**Files:**
- Modify: `config/locales/pt-BR.yml` (linhas 75 e 287)

- [ ] **Step 1: Atualizar `account_name_label`**

Em `config/locales/pt-BR.yml`, linha 75, substituir:

```yaml
      account_name_label: "Nome da empresa / imobiliária"
```

Por:

```yaml
      account_name_label: "Nome do seu negócio"
```

- [ ] **Step 2: Atualizar `handle_hint`**

Em `config/locales/pt-BR.yml`, linha 287, substituir:

```yaml
      handle_hint: "Sem @. Exemplo: imobiliariaxyz"
```

Por:

```yaml
      handle_hint: "Sem @. Exemplo: marketingdigitalxyz"
```

- [ ] **Step 3: Verificar que specs continuam passando**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec spec/requests/users/registrations_spec.rb --format documentation
```

Esperado: sem regressões.

- [ ] **Step 4: Commit**

```bash
git add config/locales/pt-BR.yml
git commit -m "refactor(i18n): copy neutra — remove referência a nicho imobiliário"
```

---

## Task 3: Criar Stimulus controller para toggle de visibilidade de senha

**Files:**
- Create: `app/javascript/controllers/password_toggle_controller.js`

**Contexto:** O projeto usa `eagerLoadControllersFrom` — criar o arquivo já o registra automaticamente. Não editar `index.js`.

- [ ] **Step 1: Criar o arquivo do controller**

Criar `app/javascript/controllers/password_toggle_controller.js` com o conteúdo:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "iconShow", "iconHide"]

  toggle() {
    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"
    this.iconShowTarget.classList.toggle("hidden")
    this.iconHideTarget.classList.toggle("hidden")
  }
}
```

- [ ] **Step 2: Confirmar que o Rails server sobe sem erros de JS**

```bash
docker compose -f docker-compose.dev.yml logs web --tail=20
```

Esperado: sem erros de importmap ou Stimulus no log. Se houver erro de importmap, verificar se o arquivo está no diretório correto.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/password_toggle_controller.js
git commit -m "feat(stimulus): add password-toggle controller for signup form"
```

---

## Task 4: Redesenhar a view de signup

**Files:**
- Modify: `app/views/devise/registrations/new.html.erb`

**Contexto crítico antes de escrever:**
- `account_name` é parâmetro flat → usar `text_field_tag "user[account_name]"`, NÃO `f.text_field`
- Cada campo de senha tem seu próprio `data-controller="password-toggle"` — estados independentes
- Logo mobile-only usa `md:hidden` (visível por padrão, oculto em md+ onde o painel esquerdo já tem logo)
- Bloco de erros usa `bg-[#c81b3a]/10 border border-[#c81b3a]/30` — sem `bg-[#fef2f2]`
- Labels seguem padrão do login: `block text-xs font-medium text-[#6b6b6b] tracking-wide uppercase mb-2`

- [ ] **Step 1: Substituir o conteúdo completo da view**

Substituir todo o conteúdo de `app/views/devise/registrations/new.html.erb` por:

```erb
<div class="min-h-screen flex flex-col md:flex-row">

  <%# ===== PAINEL ESQUERDO — Console Black (desktop only) ===== %>
  <div class="hidden md:flex w-1/2 bg-black flex-col justify-center gap-8 p-12 lg:p-16">

    <%# Logo -%>
    <%= link_to root_path, class: "text-white font-semibold text-lg tracking-tight" do %>
      ViralSpy
    <% end %>

    <%# Copy central -%>
    <div>
      <h1 class="text-4xl lg:text-[2.75rem] font-light text-white leading-tight tracking-tight mb-4">
        Comece a decifrar<br>o Instagram<br>do seu nicho.
      </h1>
      <p class="text-base text-white/50 font-light leading-relaxed max-w-sm">
        Análises automatizadas de concorrentes, sugestões de conteúdo e playbooks de crescimento. Sem achismo.
      </p>
    </div>

    <%# Card de benefícios -%>
    <div class="border border-[#0070cc]/40 rounded-xl p-5 bg-[#0070cc]/5 max-w-sm">
      <ul class="space-y-3">
        <% [
          "Primeira análise grátis",
          "BYOK — você usa suas próprias chaves",
          "Dados brutos do Instagram, sem filtro"
        ].each do |benefit| %>
          <li class="flex items-center gap-3">
            <svg class="w-5 h-5 text-[#0070cc] flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            <span class="text-sm text-white/80 font-light"><%= benefit %></span>
          </li>
        <% end %>
      </ul>
    </div>

  </div>

  <%# ===== PAINEL DIREITO — Paper White ===== %>
  <div class="w-full md:w-1/2 bg-white flex flex-col justify-center px-6 py-10 md:px-10 lg:px-16">

    <%# Logo mobile-only — md:hidden: visível por padrão, oculto em md+ onde painel esquerdo já tem logo -%>
    <div class="md:hidden mb-6">
      <%= link_to root_path, class: "text-[#0070cc] font-semibold text-lg tracking-tight" do %>
        ViralSpy
      <% end %>
    </div>

    <div class="w-full max-w-sm mx-auto">

      <h2 class="text-2xl font-light text-[#000000] tracking-tight mb-2">
        Criar conta
      </h2>
      <p class="text-sm text-[#6b6b6b] font-light mb-8">Leva menos de 1 minuto.</p>

      <%# Erros Devise — bg derivado do token Warning Red (#c81b3a), sem hex externos -%>
      <% if resource.errors.any? %>
        <div class="mb-6 rounded-xl bg-[#c81b3a]/10 border border-[#c81b3a]/30 p-4">
          <ul class="space-y-1">
            <% resource.errors.full_messages.each do |msg| %>
              <li class="text-sm text-[#c81b3a] font-light"><%= msg %></li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <%= form_for(resource, as: resource_name, url: registration_path(resource_name), html: { class: "space-y-5" }) do |f| %>

        <%# Nome do negócio — parâmetro flat, não nested attribute -%>
        <div>
          <%= label_tag "user[account_name]", t("devise.registrations.account_name_label"),
              class: "block text-xs font-medium text-[#6b6b6b] tracking-wide uppercase mb-2" %>
          <%= text_field_tag "user[account_name]", nil,
              required: true,
              autofocus: true,
              autocomplete: "organization",
              placeholder: "Ex: Marketing Pessoal, Nutrição Funcional",
              class: "w-full border border-[#cccccc] rounded-xl px-4 py-3 text-sm text-[#1f1f1f] placeholder-[#9ca3af] focus:outline-none focus:ring-2 focus:ring-[#0070cc] focus:border-transparent transition-shadow duration-150" %>
          <p class="text-xs text-[#6b6b6b] mt-1.5">Pode ser sua empresa, marca pessoal ou projeto.</p>
        </div>

        <%# Nome e Sobrenome — grid 2 colunas em md+ -%>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <%= f.label :first_name, t("devise.registrations.first_name_label"),
                class: "block text-xs font-medium text-[#6b6b6b] tracking-wide uppercase mb-2" %>
            <%= f.text_field :first_name,
                required: true,
                autocomplete: "given-name",
                class: "w-full border border-[#cccccc] rounded-xl px-4 py-3 text-sm text-[#1f1f1f] placeholder-[#9ca3af] focus:outline-none focus:ring-2 focus:ring-[#0070cc] focus:border-transparent transition-shadow duration-150" %>
          </div>
          <div>
            <%= f.label :last_name, t("devise.registrations.last_name_label"),
                class: "block text-xs font-medium text-[#6b6b6b] tracking-wide uppercase mb-2" %>
            <%= f.text_field :last_name,
                required: true,
                autocomplete: "family-name",
                class: "w-full border border-[#cccccc] rounded-xl px-4 py-3 text-sm text-[#1f1f1f] placeholder-[#9ca3af] focus:outline-none focus:ring-2 focus:ring-[#0070cc] focus:border-transparent transition-shadow duration-150" %>
          </div>
        </div>

        <%# E-mail -%>
        <div>
          <%= f.label :email, t("devise.registrations.email_label"),
              class: "block text-xs font-medium text-[#6b6b6b] tracking-wide uppercase mb-2" %>
          <%= f.email_field :email,
              required: true,
              autocomplete: "email",
              class: "w-full border border-[#cccccc] rounded-xl px-4 py-3 text-sm text-[#1f1f1f] placeholder-[#9ca3af] focus:outline-none focus:ring-2 focus:ring-[#0070cc] focus:border-transparent transition-shadow duration-150" %>
        </div>

        <%# Senha com toggle de visibilidade — controller próprio -%>
        <div>
          <%= f.label :password, t("devise.registrations.password_label"),
              class: "block text-xs font-medium text-[#6b6b6b] tracking-wide uppercase mb-2" %>
          <div class="relative" data-controller="password-toggle">
            <%= f.password_field :password,
                required: true,
                autocomplete: "new-password",
                "data-password-toggle-target": "input",
                class: "w-full border border-[#cccccc] rounded-xl px-4 py-3 pr-12 text-sm text-[#1f1f1f] placeholder-[#9ca3af] focus:outline-none focus:ring-2 focus:ring-[#0070cc] focus:border-transparent transition-shadow duration-150" %>
            <button type="button"
                    data-action="click->password-toggle#toggle"
                    class="absolute right-3 top-1/2 -translate-y-1/2 text-[#6b6b6b] hover:text-[#1f1f1f] transition-colors duration-150"
                    aria-label="Mostrar senha">
              <svg data-password-toggle-target="iconShow" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
              <svg data-password-toggle-target="iconHide" class="w-5 h-5 hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>
              </svg>
            </button>
          </div>
          <% if @minimum_password_length %>
            <p class="text-xs text-[#6b6b6b] mt-1.5">Mínimo de <%= @minimum_password_length %> caracteres.</p>
          <% end %>
        </div>

        <%# Confirmação de senha — controller próprio (estado independente do campo acima) -%>
        <div>
          <%= f.label :password_confirmation, t("devise.registrations.password_confirmation_label"),
              class: "block text-xs font-medium text-[#6b6b6b] tracking-wide uppercase mb-2" %>
          <div class="relative" data-controller="password-toggle">
            <%= f.password_field :password_confirmation,
                required: true,
                autocomplete: "new-password",
                "data-password-toggle-target": "input",
                class: "w-full border border-[#cccccc] rounded-xl px-4 py-3 pr-12 text-sm text-[#1f1f1f] placeholder-[#9ca3af] focus:outline-none focus:ring-2 focus:ring-[#0070cc] focus:border-transparent transition-shadow duration-150" %>
            <button type="button"
                    data-action="click->password-toggle#toggle"
                    class="absolute right-3 top-1/2 -translate-y-1/2 text-[#6b6b6b] hover:text-[#1f1f1f] transition-colors duration-150"
                    aria-label="Mostrar confirmação de senha">
              <svg data-password-toggle-target="iconShow" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
              <svg data-password-toggle-target="iconHide" class="w-5 h-5 hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>
              </svg>
            </button>
          </div>
        </div>

        <%# Submit — scale-[1.02] intencional em botão full-width (1.2 quebraria layout) -%>
        <%= f.submit t("devise.registrations.new.submit"),
            class: "w-full bg-[#0070cc] text-white rounded-full py-3 text-sm font-medium tracking-wide hover:bg-[#1eaedb] hover:scale-[1.02] hover:ring-2 hover:ring-[#0070cc] hover:ring-offset-2 transition-all duration-150 ease-in-out cursor-pointer mt-2" %>

      <% end %>

      <p class="mt-6 text-center text-sm text-[#6b6b6b] font-light">
        Já tem conta?
        <%= link_to "Entrar", new_session_path(resource_name),
            class: "text-[#0070cc] hover:text-[#1eaedb] font-medium transition-colors duration-150" %>
      </p>

      <p class="text-xs text-[#6b6b6b] text-center mt-8 leading-relaxed">
        Ao criar uma conta você concorda com nossos
        <%= link_to "termos de uso", "#", class: "underline underline-offset-2 hover:text-[#1f1f1f] transition-colors" %> <%# TODO: páginas legais %>
        e
        <%= link_to "política de privacidade", "#", class: "underline underline-offset-2 hover:text-[#1f1f1f] transition-colors" %>. <%# TODO: páginas legais %>
      </p>

    </div>
  </div>

</div>
```

- [ ] **Step 2: Verificar specs**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec spec/requests/users/registrations_spec.rb --format documentation
```

Esperado: todos passando. Se algum falhar com erro de seletor CSS (improvável — são request specs, não system specs), ajustar o seletor para semântico (`find('form[action="/users"]')`) sem criar novos specs.

- [ ] **Step 3: Commit**

```bash
git add app/views/devise/registrations/new.html.erb
git commit -m "refactor(ui): redesign signup view with PlayStation design system"
```

---

## Task 5: Auditoria final e verificação visual

**Files:** nenhum (apenas verificação)

- [ ] **Step 1: Auditoria de violações de estilo**

```bash
grep -rn 'style="' app/views/devise/registrations/ && echo "VIOLAÇÃO" || echo "OK"
grep -rn '<style' app/views/devise/registrations/ && echo "VIOLAÇÃO" || echo "OK"
grep -rn 'class=".*btn-\|class=".*card-' app/views/devise/registrations/ && echo "VIOLAÇÃO — classe custom" || echo "OK"
```

Esperado: todos os três retornam "OK".

- [ ] **Step 2: Rubocop**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rubocop app/controllers/users/registrations_controller.rb config/locales/pt-BR.yml
```

Esperado: `no offenses detected`.

- [ ] **Step 3: Suite completa de specs**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rspec spec/requests/users/ --format documentation
```

Esperado: 4 exemplos, 0 falhas.

- [ ] **Step 4: Screenshot desktop (1440px)**

Abrir `http://localhost:3000/users/sign_up` no browser, viewport 1440px.

Verificar:
- Painel esquerdo preto visível com logo, headline, sub copy e card de benefícios
- Painel direito branco com form completo
- 6 campos: negócio, nome, sobrenome, email, senha, confirmar senha
- Botão "Criar conta" azul pill

- [ ] **Step 5: Screenshot mobile (375px)**

Reduzir viewport para 375px.

Verificar:
- Painel esquerdo ausente (`hidden`)
- Logo ViralSpy azul visível no topo (`md:hidden`)
- Form ocupa largura total
- Nome e Sobrenome em coluna única (não grid 2 colunas)
- Botão ocupa largura total

- [ ] **Step 6: Testar toggle de senha manualmente**

1. Clicar no ícone de olho ao lado do campo "Senha" → texto visível, ícone muda para olho cortado
2. Clicar novamente → volta para mascarado
3. Repetir nos dois campos (Senha e Confirmar senha) — estados devem ser independentes

- [ ] **Step 7: Testar fluxo de erro**

Submeter o form com email inválido e senha de 2 caracteres. Verificar:
- Card de erro vermelho (`bg-[#c81b3a]/10`) aparece no topo do form
- Layout não quebra
- Form não limpa campos válidos

- [ ] **Step 8: Commit final de verificação (se houver ajustes)**

Se algum ajuste cosmético foi necessário nos steps anteriores:

```bash
git add -p  # stage apenas os ajustes
git commit -m "fix(ui): ajustes visuais pós-auditoria na view de signup"
```

Se nenhum ajuste foi necessário, não criar commit vazio.
