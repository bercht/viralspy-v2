# ViralSpy v2

Plataforma de análise de competidores e geração de sugestões estratégicas com IA, para criadores de conteúdo e marcas.

## Stack

- **Backend:** Ruby 3.3.6 + Rails 7.1
- **Frontend:** Tailwind CSS + Turbo + Stimulus + Importmap
- **Banco:** PostgreSQL 16 + pgvector
- **Cache/Fila:** Redis 7 + Sidekiq 7
- **IA:** OpenAI GPT-4o + Anthropic Claude
- **Scraping:** Apify
- **Auth:** Devise + Pundit
- **Multi-tenancy:** acts_as_tenant
- **Testes:** RSpec + FactoryBot + WebMock + VCR
- **Infra:** Docker + Docker Compose

## Pré-requisitos

- Docker Desktop instalado e rodando
- Git

## Setup local

```bash
# 1. Clonar o repositório
git clone https://github.com/bercht/viralspy-v2.git
cd viralspy-v2

# 2. Copiar e preencher variáveis de ambiente
cp .env.example .env
# Edite .env com suas chaves de API (OpenAI, Anthropic, Apify)

# 3. Subir o ambiente
docker compose -f docker-compose.dev.yml up -d

# 4. Acessar
# http://localhost:3000
```

Na primeira vez, o entrypoint já roda `db:prepare` automaticamente (cria banco e aplica migrations).

## Comandos Rails comuns

```bash
# Console Rails
docker compose -f docker-compose.dev.yml exec web bin/rails console

# Migrations
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate

# Gerar migration
docker compose -f docker-compose.dev.yml exec web bin/rails g migration NomeDaMigration

# Logs em tempo real
docker compose -f docker-compose.dev.yml logs -f web sidekiq
```

## Testes

```bash
# Rodar todos os specs
docker compose -f docker-compose.dev.yml exec web bundle exec rspec

# Rodar spec específico
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/user_spec.rb

# Rubocop
docker compose -f docker-compose.dev.yml exec web bundle exec rubocop

# ERB Lint
docker compose -f docker-compose.dev.yml exec web bundle exec erb_lint --lint-all
```

> API keys externas nunca devem aparecer em specs. Use WebMock para stubs simples e VCR para integration — cassettes ficam em `spec/fixtures/vcr_cassettes/` (sanitizados).

## Estrutura de serviços

```
app/services/
├── scraping/          # Providers de scraping (Apify, etc.)
├── llm/               # Gateway para OpenAI e Anthropic
└── analyses/          # Passos de análise (scrape → analyze → suggest)
```

Controllers chamam services. Models têm apenas associations, validations e scopes. Workers Sidekiq recebem IDs e chamam services.

## Branches e commits

- `main` — branch principal, sempre deployável
- Feature branches: `feat/nome-da-feature`
- Fix branches: `fix/nome-do-bug`

Formato de commits (Conventional Commits):
```
feat: adicionar ScrapingProvider
fix: tratar caption vazio no parser
refactor: extrair QualifierAgent
test: specs para LLM::Gateway
docs: atualizar README
chore: bump rails 7.1.5 → 7.1.6
```

## Deploy

```bash
# 1. Push para main
git push origin main

# 2. Deploy via SSH (VPS)
ssh root@<VPS_IP> "cd /opt/apps/viralspy && git pull && docker compose down && docker compose build web sidekiq && docker compose up -d"
```

## Contribuindo

1. Crie uma branch a partir de `main`
2. Faça commits atômicos com Conventional Commits
3. Certifique-se que `bundle exec rspec` e `bundle exec rubocop` passam
4. Abra um PR para `main`
