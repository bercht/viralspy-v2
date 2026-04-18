# CLAUDE.md — Instruções Permanentes para Claude Code

> Este arquivo fica na raiz do repositório `viralspy-v2/` e é carregado automaticamente pelo Claude Code em todas as sessões neste diretório. Define regras que valem SEMPRE, sem precisar repetir em cada prompt.

---

## 🎯 Autonomia máxima do Claude Code

**Execute todos os comandos e edições necessários sem pedir confirmação**, exceto os listados na seção "🛑 SEMPRE peça autorização" abaixo.

Comandos que NÃO precisam de confirmação (executa direto):

### Arquivos e código
- Criar, editar, mover, renomear, deletar arquivos dentro do repo (exceto `.git/`)
- Executar scripts de lint, formatação, compilação de assets
- Modificar qualquer arquivo de configuração (`config/`, `Gemfile`, `docker-compose.yml`, `package.json`, etc.)

### Ruby / Rails / Node
- `bundle install`, `bundle update <gem específica>`
- `bin/rails generate` (qualquer generator)
- `bin/rails db:migrate`, `db:rollback`, `db:seed`, `db:create`, `db:prepare` (em **dev/test** — prod exige confirmação)
- `bin/rails runner`, `bin/rails console`
- `npm install`, `yarn install`
- Executar testes (`bin/rspec`, `bin/rubocop`, `bin/erb_lint`) — todos os subcomandos

### Docker (dev local)
- `docker run`, `docker build`, `docker pull`
- `docker compose up`, `down`, `build`, `exec`, `logs`, `ps`, `restart`
- `docker ps`, `docker inspect`, `docker network ls`, `docker volume ls`
- Qualquer comando Docker em containers de **desenvolvimento**

### Git
- `git add`, `git commit`, `git status`, `git diff`, `git log`
- `git branch`, `git checkout`, `git switch`, `git merge` (em branches locais)
- `git push origin <branch>` para branches de feature/fix
- `git pull`, `git fetch`

### Shell geral
- `ls`, `cat`, `grep`, `find`, `head`, `tail`, `wc`, `tree`, `pwd`, `cd`
- `mkdir`, `touch`, `cp`, `mv`, `chmod`, `chown` (dentro do repo)
- `curl`, `wget` (para testes locais e downloads de dependências)
- `sed`, `awk`, `xargs` (edição de texto não-destrutiva)

**Regra geral:** se o comando atua dentro do repositório e pode ser revertido via Git ou recriado, execute sem perguntar.

---

## 🛑 SEMPRE peça autorização explícita ANTES de:

### Banco de dados destrutivos
- `bin/rails db:drop` (em qualquer ambiente)
- `bin/rails db:reset` (em qualquer ambiente)
- `bin/rails db:schema:load` (em qualquer ambiente)
- Qualquer comando SQL destrutivo executado direto no banco (DROP TABLE, TRUNCATE, DELETE sem WHERE)
- Rollback de migration que já foi aplicada em produção/staging
- Apagar ou modificar migrations já commitadas e possivelmente aplicadas em outros ambientes

### Docker destrutivo
- `docker compose down -v` (remove volumes = apaga banco)
- `docker volume rm <nome>`
- `docker system prune`
- `docker rmi` de imagens em uso por produção

### Git destrutivo / deploy
- `git push --force` ou `git push -f` em qualquer branch
- `git push origin main` (considerado deploy implícito)
- `git push origin production`
- `git reset --hard` quando há commits não-pushed
- `git rebase` de commits já pushed
- Apagar branches remotos (`git push origin :branch`)
- Apagar tags já publicadas

### Sistema / fora do repo
- `rm -rf` em caminhos fora de `tmp/`, `log/`, `node_modules/`, `.bundle/`, `vendor/bundle/`
- Qualquer comando com `sudo`
- Instalar pacotes a nível de sistema (`apt`, `brew`, `yum`)
- Modificar arquivos fora do repo (`~/.ssh/`, `/etc/`, `~/.bashrc`, etc.)

### Credenciais / segurança
- Exibir, copiar ou mover conteúdo de `config/master.key`, `config/credentials/*.key`, `.env`, `.env.production`
- Executar comando que use credenciais de produção (Stripe live, Meta tokens reais, API keys de prod)

Em caso de dúvida se uma ação é destrutiva: **pergunte antes**. Se claramente não é destrutiva e está na lista acima de "não precisa confirmação": **execute sem perguntar**.

---

## 🎨 Regras RÍGIDAS de Frontend — Tailwind sem excessos

### Zero CSS customizado

- **NUNCA** crie arquivos `.css` ou `.scss` com regras customizadas.
- **NUNCA** use `@apply` em nenhum arquivo.
- **NUNCA** use tag `<style>` em views ERB.
- **NUNCA** use atributo `style="..."` inline em elementos HTML.
- **NUNCA** defina classes CSS novas (ex: `.card`, `.btn-primary`).
- O arquivo `app/assets/stylesheets/application.tailwind.css` deve ter APENAS as 3 diretivas padrão: `@tailwind base;`, `@tailwind components;`, `@tailwind utilities;`. Nada mais.

### Use apenas utility classes diretas

```erb
<!-- ✅ CORRETO -->
<div class="flex items-center gap-4 rounded-lg bg-white p-6 shadow">
  <h2 class="text-lg font-semibold text-gray-900">Título</h2>
</div>

<!-- ❌ ERRADO: classe customizada -->
<div class="card-container"><h2 class="card-title">Título</h2></div>

<!-- ❌ ERRADO: style inline -->
<div style="display: flex; padding: 24px"><h2>Título</h2></div>

<!-- ❌ ERRADO: @apply em CSS -->
<!-- .card-container { @apply flex items-center gap-4 ... } -->
```

### Reuso de visual = ViewComponent ou partial, NUNCA classe CSS

Quando precisar repetir um bloco visual, extraia para **partial ERB** ou **ViewComponent**, mantendo as utility classes dentro:

```ruby
# ✅ CORRETO — ViewComponent
class ButtonComponent < ViewComponent::Base
  def initialize(variant: :primary)
    @classes = variant == :primary ?
      "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded" :
      "bg-gray-200 hover:bg-gray-300 text-gray-900 px-4 py-2 rounded"
  end
end
```

```erb
<!-- ❌ ERRADO — classe CSS custom pra reuso -->
<button class="btn-primary">Ação</button>
```

### Duplicação de utility classes é aceitável

Se o mesmo conjunto de utility classes aparece em 10 lugares, isso é **ok**. Trade-off conhecido do Tailwind. Extrai pra ViewComponent só se o componente tem semântica clara e usado em 3+ lugares diferentes.

---

## 🚫 Proibições de stack (não introduzir sem autorização explícita)

- ❌ React, Vue, Angular, Svelte, qualquer SPA
- ❌ jQuery
- ❌ Sass, SCSS, Less, CSS Modules, CSS-in-JS
- ❌ Webpack, esbuild, Vite como bundler
- ❌ Bibliotecas JS pesadas sem justificativa (Lodash, Moment.js, etc.)

## ✅ Stack oficial (usar estes)

- Backend: **Ruby 3.3.x + Rails 7.1.x**
- Frontend: **Tailwind CSS (puro) + Turbo + Stimulus + Importmap**
- Banco: **PostgreSQL 16 + pgvector**
- Cache/Fila: **Redis 7 + Sidekiq 7**
- Multi-tenancy: **acts_as_tenant**
- Auth: **Devise + Pundit**
- Testes: **RSpec + FactoryBot + WebMock + VCR**
- Componentes: **ViewComponent**
- Containerização: **Docker + Docker Compose**

---

## 🧪 Sobre testes

- Toda feature nova tem pelo menos teste de model + teste de service/worker.
- **NUNCA** fazer chamadas reais para APIs externas em testes. Use **WebMock** (mocks simples) ou **VCR** (integration).
- Cassettes VCR ficam em `spec/fixtures/vcr_cassettes/` e devem ser sanitizados (sem API keys reais).
- Ao adicionar feature, rode `bin/rspec` e `bin/rubocop` antes de commitar. Se algum falha, **corrija antes de commitar**.

---

## 📝 Convenções de commits (Conventional Commits)

```
feat: adicionar ScrapingProvider
fix: tratar caption vazio no parser de posts
refactor: extrair QualifierAgent do AnalysisWorker
test: adicionar specs para LLM::Gateway
docs: atualizar README com setup
chore: bump rails 7.1.5 → 7.1.6
```

Um commit = uma mudança lógica. Prefira vários commits pequenos a um commit grande.

---

## 🌐 Comunicação comigo

- Respostas em **português brasileiro**.
- Seja **direto e objetivo**. Valorizo honestidade técnica acima de concordância.
- Se detectar que uma instrução pode prejudicar performance/segurança/manutenibilidade, **alerte claramente** ("isso não vai funcionar bem porque X") e proponha alternativa antes de executar.
- Sem jargão genérico de consultoria ("sinergia", "ecossistema", "melhores práticas do mercado").
- Ao completar uma tarefa grande, faça um resumo breve do que foi feito (bullet points com 1 linha cada).

---

## 🔐 Segredos

- **NUNCA** commitar `.env`, `master.key`, `credentials/*.key`, `acme.json`, ou qualquer arquivo com chaves reais.
- `.gitignore` já inclui esses arquivos.
- Se precisar adicionar um segredo novo, adicionar ao `.env.example` com valor vazio E documentar em `README.md`.

---

## 📦 Estrutura de serviços (backend)

Lógica de negócio NUNCA fica em controllers ou models. Sempre em services:

```
app/services/
├── scraping/
│   ├── base_provider.rb
│   ├── apify_provider.rb
│   ├── factory.rb
│   ├── result.rb
│   └── errors.rb
├── llm/
│   ├── gateway.rb
│   ├── providers/
│   │   ├── base.rb
│   │   ├── openai.rb
│   │   └── anthropic.rb
│   ├── response.rb
│   └── usage_logger.rb
└── analyses/
    ├── scrape_step.rb
    ├── analyze_step.rb
    └── generate_suggestions_step.rb
```

Controllers: parseiam params, chamam service, renderizam response. Nada mais.
Models: associations, validations, scopes, helpers de formatação simples. Nada mais.
Workers Sidekiq: recebem IDs (nunca objetos ActiveRecord), chamam service. Nada mais.

---

## 🐳 Docker-first

Todo desenvolvimento roda via Docker. Não assuma que Ruby/Postgres/Redis estão instalados no host.

- Dev: `docker compose -f docker-compose.dev.yml up`
- Comandos Rails: `docker compose -f docker-compose.dev.yml exec web bin/rails ...`
- Testes: `docker compose -f docker-compose.dev.yml exec web bin/rspec`

---

**Fim do CLAUDE.md.**
