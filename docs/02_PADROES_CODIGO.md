# 02_PADROES_CODIGO — Convenções e Regras Rígidas

> Regras marcadas 🔒 são **inegociáveis no MVP**. Quebrar implica retrabalho. Regras marcadas ⚙️ são preferências fortes, mas com flexibilidade pontual justificada.

---

## Frontend (🔒 regras rígidas)

### CSS e estilo

🔒 **Apenas utility classes do Tailwind padrão.**
- Não criar classes CSS utilitárias próprias (`.btn`, `.card`) nem usar `@apply`
- Não adicionar arquivos `.css` ou `.scss` fora do diretório `app/assets/tailwind/`
- Não usar `<style>` tags em ERB/HTML
- Não usar atributo `style="..."` em elementos HTML
- Tokens de tema em `app/assets/tailwind/application.css` via bloco `@theme {}` (Tailwind v4) **são permitidos** — não são classes customizadas, são variáveis de tema

✅ **Correto:**
```erb
<div class="flex items-center gap-4 rounded-lg bg-white p-6 shadow">
  <h2 class="text-lg font-semibold text-gray-900">Título</h2>
</div>
```

❌ **Errado:**
```erb
<div class="card-container" style="display: flex">
  <h2 class="card-title">Título</h2>
</div>
```

❌ **Errado (em `app/assets/tailwind/application.css`):**
```css
.card-container { @apply flex items-center gap-4 rounded-lg bg-white p-6 shadow; }
```

### JavaScript

🔒 **Todo comportamento interativo vai em Stimulus controllers.**
- Não usar `<script>` inline em views
- Não usar `jQuery`
- Não adicionar libraries JavaScript pesadas sem ADR
- Controladores Stimulus ficam em `app/javascript/controllers/`
- Registro automático via `bin/importmap`

✅ **Correto:**
```erb
<div data-controller="copy-to-clipboard" data-copy-to-clipboard-text-value="Olá mundo">
  <button data-action="click->copy-to-clipboard#copy">Copiar</button>
</div>
```

```javascript
// app/javascript/controllers/copy_to_clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue)
  }
}
```

❌ **Errado:**
```erb
<button onclick="navigator.clipboard.writeText('Olá mundo')">Copiar</button>
```

### Turbo

⚙️ **Preferir Turbo Frames e Turbo Streams para atualizações parciais.**
- Listas com filtros → Turbo Frame
- Atualizações pós-action → Turbo Stream
- Progress de background job → `turbo_stream_from` via ActionCable

### Componentização

⚙️ **Usar partials ERB para componentização. ViewComponent não é usado no MVP.**
- Partials compartilhadas ficam em `app/views/shared/` ou subdiretório do contexto
- Extrair para partial quando o bloco aparece em 3+ lugares com semântica clara
- ViewComponent (gem instalada) fica para reavaliar se o app crescer para >30 componentes compartilhados

---

## Backend (🔒 regras rígidas)

### Estrutura de diretórios

```
app/
├── components/          # ViewComponents (gem instalada, não usado no MVP)
├── controllers/         # Controllers Rails padrão
│   └── api/v1/          # API REST (namespace reservado)
├── jobs/                # ActiveJob (não usar, prefira workers Sidekiq)
├── models/              # ActiveRecord models
├── policies/            # Pundit policies
├── serializers/         # Serializers para API REST
├── services/            # Lógica de negócio (padrão obrigatório)
│   ├── scraping/
│   ├── llm/
│   ├── transcription/
│   └── analyses/
├── views/               # ERB views
└── workers/             # Sidekiq workers
```

🔒 **Lógica de negócio NUNCA fica em controllers ou models.**
- Controllers: apenas parsing de params, chamar service, render response
- Models: apenas associations, validations, scopes e helpers de formatação
- Services: orquestram a lógica de negócio, podem chamar outros services

### Gems com versão pinada

⚠️ **Versões de gems de cliente LLM são travadas no `Gemfile.lock`**, não com pin explícito no `Gemfile`. Mudanças minor podem quebrar mocks silenciosamente (shapes de response diferentes).

Gems de cliente com atenção especial:

| Gem | Observação |
|---|---|
| `ruby-openai` | Retorna Hash; stubs WebMock funcionam diretamente |
| `anthropic` | Retorna **objetos Ruby** com métodos (não Hash) — mocks exigem `instance_double` |
| `assemblyai` | Pinada com `~> 1.0` no Gemfile |

**Quando bumpar gems de cliente LLM:**

1. Ler CHANGELOG da gem entre versões
2. Rodar `bin/rspec spec/services/llm/` e `bin/rspec spec/services/transcription/`
3. Se algum spec quebrar por mudança de API da gem, ajustar o provider + mocks
4. Commit separado: `chore(deps): bump <gem> from X to Y`

### Acrônimos em nomes de classe, módulo e constantes

🔒 **Todo acrônimo usado em nome de constante Ruby deve estar registrado em
`config/initializers/inflections.rb` antes de criar o arquivo correspondente.**

O Zeitwerk usa a tabela de inflections do Rails pra resolver o autoload:
`app/services/llm/gateway.rb` → `LLM::Gateway` (correto) vs. `Llm::Gateway`
(errado, quebra autoload).

**Inflections registrados atualmente (Fase 1.4):**
- `LLM`
- `AI`

**Procedimento ao criar arquivo com acrônimo novo:**

1. Abrir `config/initializers/inflections.rb`
2. Adicionar o acrônimo:
   ```ruby
   ActiveSupport::Inflector.inflections(:en) do |inflect|
     inflect.acronym "LLM"
     inflect.acronym "AI"
     inflect.acronym "SEU_ACRONIMO_NOVO"
   end
   ```
3. Reiniciar servidor Rails / Sidekiq
4. Só então criar o arquivo `app/services/seu_acronimo_novo/...`

**Sinal de que falta inflection:** `NameError: uninitialized constant X`
apesar do arquivo existir, ou Zeitwerk reclamando de mismatch de nome.

**Exceção:** módulos/classes que não contêm acrônimo não precisam de nada
extra (ex: `Scraping::ApifyProvider` não precisa — "Apify" é tratado como
palavra comum em camelCase pelo Rails).

**Nota sobre `Transcription::Providers::OpenAI`:** o acrônimo `OpenAI` no Rails
é tratado como `Open` + `AI` em camelCase, então a inflection de `AI` já cobre.
O arquivo fica em `app/services/transcription/providers/open_ai.rb`.

**Regra prática:** se o nome da constante Ruby tem 2+ letras maiúsculas
consecutivas que representam sigla, é acrônimo e precisa de inflection.

### Persistência de filhos antes de `update!` no pai

🔒 **Ao persistir filhos (ex: `Post`) em bulk dentro de um service que depois
chama `parent.update!` (ex: `analysis.update!`), use `Post.new(analysis: ...)`
e NÃO `analysis.posts.new(...)`.**

**O problema:**

Quando você faz `analysis.posts.new(...)`, o post entra no grafo da association
em memória. Se algum post é inválido (não passa `save!`), ele permanece no grafo.
Quando depois você chama `analysis.update!(posts_scraped_count: ...)`, o Rails
**tenta auto-salvar os posts do grafo de novo**, e o post inválido derruba o
`update!` com `ActiveRecord::RecordInvalid`.

**Exemplo do problema (NÃO FAZER):**

```ruby
# ❌ ERRADO — pega em produção se 1 post for inválido
posts_hash_array.each do |h|
  post = analysis.posts.new(
    account: account,
    instagram_post_id: h[:instagram_post_id],
    # ...
  )
  post.save!
rescue ActiveRecord::RecordInvalid
  # Pula post inválido — mas ele continua no grafo da association
end

analysis.update!(posts_scraped_count: analysis.posts.count)
# ↑ BOOM. Rails tenta salvar de novo todos os posts, inclusive o inválido.
```

**Correto:**

```ruby
# ✅ CORRETO — posts inválidos não contaminam o grafo
posts_hash_array.each do |h|
  post = Post.new(
    analysis: analysis,
    account: account,
    competitor: competitor,
    instagram_post_id: h[:instagram_post_id],
    # ...
  )
  post.save!
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.warn("Failed to persist post: #{e.message}")
  # Pula — o post não entrou no grafo da association
end

analysis.update!(posts_scraped_count: analysis.posts.count)
# ↑ Funciona. Rails não tenta re-salvar nada.
```

**Quando aplicar:**
- Qualquer step/service que persiste em bulk filhos de um agregado e depois
  atualiza campos do pai
- Especialmente quando pode haver posts inválidos (dados externos como Apify)

**Quando NÃO se aplica:**
- Em controllers simples que usam `resource.children.create!` e não chamam
  `update!` depois
- Quando todos os filhos passam validação com certeza (improvável com dados
  externos)

**Descoberto na Fase 1.5a** (`Analyses::ScrapeStep`). Fica como padrão pra
qualquer step futuro que manipule Posts + Analysis juntos (TranscribeStep,
futuros pipelines).

### Padrão de Service Objects

🔒 **Services sempre têm entrada e saída explícitas.**

```ruby
# app/services/analyses/scrape_step.rb
module Analyses
  class ScrapeStep
    def self.call(analysis)
      new(analysis).call
    end

    def initialize(analysis)
      @analysis = analysis
    end

    def call
      # lógica aqui
      Result.new(success: true, data: ...)
    end

    private

    attr_reader :analysis
  end
end
```

⚙️ **Serviços complexos retornam objeto `Result` com `success?`, `data`, `error`.**

### Workers Sidekiq

🔒 **Workers têm UMA responsabilidade e chamam services.**

```ruby
# app/workers/analyses/run_analysis_worker.rb
module Analyses
  class RunAnalysisWorker
    include Sidekiq::Worker
    sidekiq_options queue: 'analyses', retry: 2

    def perform(analysis_id)
      analysis = Analysis.find(analysis_id)
      ActsAsTenant.with_tenant(analysis.account) do
        Analyses::ScrapeStep.call(analysis)
        return if analysis.failed?

        Analyses::AnalyzeStep.call(analysis)
        return if analysis.failed?

        Analyses::GenerateSuggestionsStep.call(analysis)
      end
    end
  end
end
```

🔒 **Workers sempre recebem IDs, nunca objetos ActiveRecord** (deserialização Sidekiq).

### Controllers

⚙️ **Controllers finos, usando padrão Rails.**

```ruby
class CompetitorsController < ApplicationController
  before_action :authenticate_user!

  def index
    @competitors = current_tenant.competitors.includes(:analyses).recent
  end

  def create
    @competitor = current_tenant.competitors.build(competitor_params)
    if @competitor.save
      redirect_to @competitor, notice: 'Concorrente adicionado.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def competitor_params
    params.require(:competitor).permit(:instagram_handle)
  end
end
```

### Models

⚙️ **Model contém associations, validations, scopes, callbacks simples.**

```ruby
class Competitor < ApplicationRecord
  acts_as_tenant :account
  has_many :analyses, dependent: :destroy

  validates :instagram_handle, presence: true,
    format: { with: /\A[a-zA-Z0-9_.]{1,30}\z/ },
    uniqueness: { scope: :account_id, case_sensitive: false }

  before_validation :normalize_handle

  scope :recent, -> { order(created_at: :desc) }

  private

  def normalize_handle
    self.instagram_handle = instagram_handle.to_s.strip.delete('@').downcase
  end
end
```

🔒 **Evitar callbacks que fazem side effects pesados** (chamar APIs, enviar email, etc). Isso vai em services.

### Policies (Pundit)

⚙️ **Toda ação de mutação (create, update, destroy) passa por policy check.**

```ruby
def destroy
  @competitor = current_tenant.competitors.find(params[:id])
  authorize @competitor
  @competitor.destroy
  redirect_to competitors_path, notice: 'Removido.'
end
```

---

## Banco de dados

### Migrations

🔒 **Migrations devem ser reversíveis.** Usar `change` quando possível, `up`/`down` quando não.

🔒 **Não usar `remove_column` ou `drop_table` sem plano de rollback.** Em produção, deprecar primeiro, remover numa segunda migration posterior.

⚙️ **Indexes:**
- Foreign keys → sempre index
- Campos usados em queries frequentes → index
- Queries compostas → index composto
- JSONB com queries frequentes → index GIN

### Nomenclatura

- Tabelas: plural, snake_case (`content_suggestions`, `llm_usage_logs`)
- Colunas: snake_case (`posts_analyzed_count`)
- Foreign keys: `singular_name_id` (`competitor_id`)
- Timestamps: sempre `created_at` e `updated_at`
- Soft delete: `deleted_at` (usar `paranoia` gem apenas se necessário)

> **Nota:** nomes de tabela em snake_case são independentes do nome da
> constante Ruby. A tabela `llm_usage_logs` mapeia pra constante `LLMUsageLog`
> via inflection registrada. Ver seção "Acrônimos em nomes de classe".

---

## Testes

### RSpec

🔒 **Toda feature tem pelo menos teste de model + teste de service ou worker.**
🔒 **shoulda-matchers NÃO funciona com `acts_as_tenant` + `require_tenant = true`.**

Matchers do tipo `validate_presence_of`, `belong_to`, `have_many` invocam
internamente `subject.new` ou `described_class.new` sem tenant ativo, o que
dispara `ActsAsTenant::Errors::NoTenantSet` antes do matcher conseguir testar
qualquer coisa. Essa limitação foi descoberta na Fase 1.2 e vale pros 6
modelos de domínio (Competitor, Analysis, Post, ContentSuggestion,
LLMUsageLog, TranscriptionUsageLog).

Padrão correto: escrever validations/associations explicitamente, envolvendo
em `ActsAsTenant.with_tenant(account)`.

❌ NÃO FUNCIONA:
```ruby
it { is_expected.to validate_presence_of(:instagram_handle) }
```

✅ FUNCIONA:
```ruby
it 'requires instagram_handle' do
  ActsAsTenant.with_tenant(account) do
    competitor = build(:competitor, account: account, instagram_handle: nil)
    expect(competitor).not_to be_valid
    expect(competitor.errors[:instagram_handle]).to be_present
  end
end
```

shoulda-matchers continua útil em modelos que **NÃO** usam acts_as_tenant
(User, Account).

⚙️ **Estrutura:**
- `spec/models/` — validations, associations, scopes
- `spec/services/` — lógica de serviço
- `spec/workers/` — workers Sidekiq (com `Sidekiq::Testing.inline!` quando apropriado)
- `spec/requests/` — controllers (preferir sobre `spec/controllers/`)
- `spec/system/` — fluxos end-to-end via Capybara (poucos, críticos)

### Mocks de API externa

🔒 **Nunca fazer chamada real para Apify/OpenAI/Anthropic em testes.**

- **WebMock** para unit tests:
  ```ruby
  stub_request(:post, 'https://api.apify.com/v2/acts/...')
    .to_return(body: File.read('spec/fixtures/apify_run_response.json'))
  ```

- **VCR** para integration tests:
  ```ruby
  VCR.use_cassette('analyze_competitor_natgeo') do
    # test body
  end
  ```

- **Sanitização**: configurar VCR/WebMock para filtrar headers com chaves API

### Mocks de gems cliente (OpenAI, Anthropic, etc)

🔒 **Atenção ao shape do response das gems cliente.** Algumas gems retornam
Hash cru do JSON da API; outras retornam objetos Ruby com métodos. Mockar
cada tipo exige abordagem diferente.

**Exemplos documentados (Fase 1.4):**

- **`ruby-openai` 8.3.0** — retorna Hash (ex: `response["choices"][0]["message"]["content"]`).
  Stubs WebMock podem retornar JSON direto e a gem parseia normalmente.

- **`anthropic` 1.35.0** — retorna **objetos Ruby** com métodos
  (`.content`, `.usage.input_tokens`, `.stop_reason`). Chamada é
  `client.messages.create(**params)`, **não** `client.messages(parameters:)`.
  Mockar esta gem exige criar objetos (ou doubles com os métodos esperados),
  **NÃO retornar Hash**.

⚠️ **Antes de mockar qualquer gem cliente, rodar `bundle info <gem>` e
consultar a documentação da versão instalada.** Código de referência de
specs pode ficar stale rápido conforme gems evoluem.

**Padrão de mock para gem com objetos Ruby (exemplo Anthropic):**

```ruby
# spec/services/llm/providers/anthropic_spec.rb
let(:fake_response) do
  # NÃO: usar Hash { content: [...], usage: {...} }
  # SIM: criar double com os métodos que o provider acessa
  instance_double(
    "Anthropic::Models::Message",
    content: [instance_double("Anthropic::Models::ContentBlock", text: "Hi", type: "text")],
    usage: instance_double("Anthropic::Models::Usage", input_tokens: 10, output_tokens: 5),
    model: "claude-3-5-sonnet-20241022",
    stop_reason: "end_turn"
  )
end

before do
  allow_any_instance_of(Anthropic::Client)
    .to receive_message_chain(:messages, :create)
    .and_return(fake_response)
end
```

O nome exato das classes (`Anthropic::Models::Message` etc.) vem da gem
instalada — checar `bundle show anthropic` pra paths reais.

### Factories

⚙️ **Factories simples, com traits para variações.**

```ruby
FactoryBot.define do
  factory :competitor do
    association :account
    instagram_handle { Faker::Internet.username }

    trait :with_analysis do
      after(:create) { |c| create(:analysis, competitor: c, account: c.account) }
    end
  end
end
```

---

## Linting

### Rubocop

🔒 **`bin/rubocop` deve passar em todo commit.**

- Config baseada em `rubocop-rails-omakase`
- Exceções documentadas em `.rubocop.yml` com comentário explicando razão
- `rubocop:disable` inline somente com comentário `# rubocop:disable RuleName -- motivo`

### ERB Lint

🔒 **`bin/erb_lint --lint-all` deve passar.**

- Config em `.erb-lint.yml`
- Linters ativos: `ErbSafety`, `FinalNewline`, `TrailingWhitespace`, `ParserErrors`

---

## Segurança

### Secrets

🔒 **Zero segredos no código.**

- `.env` nunca commitado (está no `.gitignore`)
- Chaves API do produto → `ENV['...']` em produção, `credentials.yml.enc` em dev
- Chaves de usuário (futuro BYOK) → `encrypts :api_key` no model

### Autenticação e autorização

🔒 **Toda action web autenticada por padrão.**

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  # ...
end
```

Endpoints públicos (landing, signup) explicitamente liberados:
```ruby
skip_before_action :authenticate_user!, only: [:show_landing]
```

### Multi-tenancy

🔒 **Toda query de recurso tenant-scoped tem que usar `ActsAsTenant`.**

- `require_tenant = true` no config
- Evitar `ActsAsTenant.without_tenant` (se usar, comentar o motivo)
- Em workers, abrir bloco `ActsAsTenant.with_tenant(account)` antes de operar

### Rate limiting

⚙️ **Usar `rack-attack` para rate limiting de endpoints públicos.**
- Signup: máx 5 por IP por hora
- API: tokens com limites configuráveis
- Scraping: máx 1 análise simultânea por competitor

---

## Convenções de Git

### Branches

```
main                      # branch principal, deploy staging automático
feature/fase-X-descricao  # features atômicas
fix/descricao             # bugfixes
refactor/descricao        # refactors sem mudança de comportamento
```

### Commits (Conventional Commits)

```
feat: add apify scraping provider
fix: handle empty caption in post parser
refactor: extract qualifier agent from analysis worker
test: add specs for LLM::Gateway error handling
docs: update README with deploy instructions
chore: bump rails to 7.1.5
```

🔒 **Uma feature = um PR = múltiplos commits atômicos.**

### Pull Requests

- Descrição clara do que foi feito e por quê
- Checklist de testes rodados
- Rubocop e ERB Lint verdes
- Review (self-review se solo) antes de merge

---

## Observabilidade

### Logs

⚙️ **Usar `Rails.logger` estruturado.**

```ruby
Rails.logger.info("Starting analysis", analysis_id: analysis.id, account_id: account.id)
```

Evitar `puts` ou `print` em produção.

### Erros

⚙️ **Capturar exceções em services com contexto.**

```ruby
rescue => e
  Rails.logger.error("Scraping failed", error: e.message, backtrace: e.backtrace.first(5), analysis_id: analysis.id)
  raise
end
```

### Métricas futuras

Quando produto maduro:
- Sentry para errors
- New Relic ou Datadog para APM
- Custom dashboards para cost-per-analysis

No MVP: Rails logs + Sidekiq dashboard é suficiente.

---

## Performance

### N+1

🔒 **Usar `includes` ou `preload` sempre que iterar sobre associação.**

```ruby
# ❌ N+1
@competitors.each { |c| puts c.analyses.count }

# ✅ correto
@competitors.includes(:analyses).each { |c| puts c.analyses.size }
```

⚙️ **Usar gem `bullet` em desenvolvimento para detectar.**

### Queries

⚙️ **Queries pesadas em background via Sidekiq.**

⚙️ **Cache Redis para dados frequentemente acessados.**
```ruby
Rails.cache.fetch("competitor:#{id}:stats", expires_in: 1.hour) do
  competitor.compute_stats
end
```

---

## Internationalização (i18n)

⚙️ **Strings de UI em `config/locales/pt-BR.yml`.**

🔒 **Locale padrão:** `pt-BR`. Sem inglês em UI.

⚙️ **Strings de erro técnico** (logs, exceções) podem ficar em inglês.

---

## Acessibilidade

⚙️ **Mínimo semântico:**
- Usar tags HTML semânticas (`<button>`, `<nav>`, `<main>`)
- `aria-label` em ícones sem texto visível
- Contraste mínimo WCAG AA
- Focus visível em elementos interativos

---

**Última atualização:** Fase 1.6 T5 — Interface Web concluída. Regra CSS: @theme tokens permitidos em `app/assets/tailwind/application.css` (Tailwind v4). ViewComponent: não usado no MVP, reavaiar com >30 componentes. Gems de cliente: versões no Gemfile.lock (não pin explícito). Naming: `Transcription::Providers::OpenAI`/`AssemblyAI` com namespace correto. Novas seções: broadcasts Turbo Stream, decisão ViewComponents.
