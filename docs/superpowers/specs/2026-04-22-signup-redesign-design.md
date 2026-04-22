# Spec: Redesign da View de Signup — PlayStation Design System

**Data:** 2026-04-22
**Status:** Aprovado

---

## Objetivo

Refatorar `app/views/devise/registrations/new.html.erb` aplicando o mesmo design system PlayStation Inspired já usado na tela de login (`devise/sessions/new`). Zero mudanças de comportamento — apenas apresentação.

---

## Contexto e Decisões Confirmadas

### Parâmetros do controller (intocáveis)

| Campo no form | Param Rails | Método no controller |
|---|---|---|
| `text_field_tag "user[account_name]"` | `params[:user][:account_name]` | `account_params` |
| `f.text_field :first_name` | `params[:user][:first_name]` | `sign_up_params` |
| `f.text_field :last_name` | `params[:user][:last_name]` | `sign_up_params` |
| `f.email_field :email` | `params[:user][:email]` | `sign_up_params` |
| `f.password_field :password` | `params[:user][:password]` | `sign_up_params` |
| `f.password_field :password_confirmation` | `params[:user][:password_confirmation]` | `sign_up_params` |

**Nota:** `account_name` é um parâmetro flat — não é nested attribute. Usar `text_field_tag "user[account_name]"` diretamente, não `f.text_field`.

### Decisões de design

- **Layout:** abordagem A — espelhar o login exatamente. Painel esquerdo `hidden md:flex`, right panel scrollável no mobile. Consistência com login é o maior ganho.
- **Locale:** atualizar chaves no `pt-BR.yml` em vez de hardcodar labels na view (evita drift).
- **`password_confirmation`:** campo estava ausente no form atual — precisa ser adicionado.
- **`layout "marketing"`:** faltava no `RegistrationsController` — adicionar.
- **Scale em botão full-width:** `scale-[1.02]` em vez de `scale-[1.2]` — botão full-width com 1.2 quebra layout visual; 1.02 preserva a intenção de feedback tátil sem artefato.

---

## Artefatos a Criar/Modificar

### 1. `app/views/devise/registrations/new.html.erb` (modificar)

Estrutura raiz:

```erb
<div class="min-h-screen flex flex-col md:flex-row">

  <%# Painel esquerdo — Console Black (desktop only) %>
  <div class="hidden md:flex w-1/2 bg-black flex-col justify-center gap-8 p-12 lg:p-16">
    <%# Logo %>
    <%# Headline: "Comece a decifrar o Instagram do seu nicho." %>
    <%# Sub copy %>
    <%# Card de benefícios com 3 bullets %>
  </div>

  <%# Painel direito — Paper White %>
  <div class="w-full md:w-1/2 bg-white flex flex-col justify-center px-6 py-10 md:px-10 lg:px-16">
    <%# Logo mobile-only %>
    <div class="w-full max-w-sm mx-auto">
      <%# Headline "Criar conta" %>
      <%# Subtítulo %>
      <%# Bloco de erros (conditional) %>
      <%# Form %>
    </div>
  </div>

</div>
```

**Painel esquerdo — detalhes:**

- Logo: `link_to root_path`, `text-white font-semibold text-lg tracking-tight`
- Headline: Outfit `font-light`, `text-4xl lg:text-[2.75rem]`, `leading-tight tracking-tight text-white`
- Sub copy: `text-base text-white/50 font-light leading-relaxed max-w-sm`
- Card de benefícios: `border border-[#0070cc]/40 rounded-xl p-5 bg-[#0070cc]/5 max-w-sm`
  - 3 itens com check SVG (`text-[#0070cc]`, 20×20) + texto `text-sm text-white/80 font-light`
  - "Primeira análise grátis"
  - "BYOK — você usa suas próprias chaves"
  - "Dados brutos do Instagram, sem filtro"

**Painel direito — form:**

- Labels: `block text-xs font-medium text-[#6b6b6b] tracking-wide uppercase mb-2` (igual ao login)
- Inputs: `w-full border border-[#cccccc] rounded-xl px-4 py-3 text-sm text-[#1f1f1f] placeholder-[#9ca3af] focus:outline-none focus:ring-2 focus:ring-[#0070cc] focus:border-transparent transition-shadow duration-150`
- Inputs de senha: wrapper `relative` com botão toggle absoluto `right-3 top-1/2 -translate-y-1/2`, `pr-12` no input
- Grid 2 colunas para first_name/last_name: `grid grid-cols-1 md:grid-cols-2 gap-4`
- Botão submit: `w-full bg-[#0070cc] text-white rounded-full py-3 text-sm font-medium tracking-wide hover:bg-[#1eaedb] hover:scale-[1.02] hover:ring-2 hover:ring-[#0070cc] hover:ring-offset-2 transition-all duration-150 ease-in-out cursor-pointer`
- Helper text senha: `text-xs text-[#6b6b6b] mt-1.5` com `@minimum_password_length`
- Footer legal: `text-xs text-[#6b6b6b] text-center mt-8`, links para `#` com comentário `<!-- TODO: páginas legais -->`

**Bloco de erros:**

```erb
<% if resource.errors.any? %>
  <div class="mb-6 rounded-xl bg-[#fef2f2] border border-[#c81b3a]/20 p-4">
    <ul class="space-y-1">
      <% resource.errors.full_messages.each do |msg| %>
        <li class="text-sm text-[#c81b3a] font-light"><%= msg %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

### 2. `app/javascript/controllers/password_toggle_controller.js` (criar)

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

Registrar em `app/javascript/controllers/index.js` (padrão do projeto).

**Markup do input com toggle:**

```erb
<div class="relative" data-controller="password-toggle">
  <%= f.password_field :password,
      autocomplete: "new-password",
      required: true,
      "data-password-toggle-target": "input",
      class: "w-full border border-[#cccccc] rounded-xl px-4 py-3 pr-12 ..." %>
  <button type="button"
          data-action="click->password-toggle#toggle"
          class="absolute right-3 top-1/2 -translate-y-1/2 text-[#6b6b6b] hover:text-[#1f1f1f] transition-colors"
          aria-label="Mostrar senha">
    <!-- olho aberto -->
    <svg data-password-toggle-target="iconShow" ...></svg>
    <!-- olho fechado -->
    <svg data-password-toggle-target="iconHide" class="hidden" ...></svg>
  </button>
</div>
```

Cada campo de senha tem seu próprio `data-controller="password-toggle"` — estados independentes.

### 3. `app/controllers/users/registrations_controller.rb` (modificar)

Adicionar apenas:

```ruby
layout "marketing"
```

Nenhuma outra alteração no controller.

### 4. `config/locales/pt-BR.yml` (modificar)

```yaml
# Atualizar:
account_name_label: "Nome do seu negócio"   # era: "Nome da empresa / imobiliária"

# Atualizar (competitors form):
handle_hint: "Sem @. Exemplo: marketingdigitalxyz"  # era: "Sem @. Exemplo: imobiliariaxyz"
```

---

## Regras de Estilo (não violar)

- Zero `<style>` tags
- Zero `style="..."` inline (exceto `--progress: X%` dinâmico — não se aplica aqui)
- Zero classes CSS custom
- Apenas Tailwind utility classes
- Zero JavaScript fora de Stimulus

---

## Responsividade

| Largura | Comportamento |
|---|---|
| 375px | Form ocupa tela inteira; logo ViralSpy aparece no topo (mobile-only); painel esquerdo `hidden` |
| 768px | Grid 2 colunas ativa; padding reduzido |
| 1024px+ | Layout final completo |

---

## Critérios de Aceite

1. `bin/rails server` sobe sem erros
2. `/users/sign_up` renderiza com layout `marketing` (sem navbar de app)
3. Signup válido cria Account + User (fluxo intocado)
4. Signup inválido exibe erros no card vermelho, form não quebra
5. Toggle de senha funciona independentemente em cada campo
6. Link "Já tem conta?" → `/users/sign_in`
7. Auditoria limpa:
   ```bash
   grep -rn 'style="' app/views/devise/registrations/ && echo "VIOLAÇÃO" || echo "OK"
   grep -rn '<style' app/views/devise/registrations/ && echo "VIOLAÇÃO" || echo "OK"
   ```
8. `bin/rubocop` passa
9. `bin/rspec spec/system/ spec/requests/users/` verde (sem criar specs novos; ajustar seletores quebrados se necessário)

---

## Commit

```
refactor(ui): redesign signup view with PlayStation design system
```
