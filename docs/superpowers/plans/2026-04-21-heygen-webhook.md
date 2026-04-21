# HeyGen Webhook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar endpoint `POST /webhooks/heygen` que recebe callbacks da HeyGen e atualiza `GeneratedMedia` imediatamente, sem depender do polling.

**Architecture:** Controller fora de qualquer autenticação Devise/tenant verifica assinatura HMAC-SHA256, localiza `GeneratedMedia` por `provider_job_id` sem tenant, atualiza status e faz broadcast Turbo Stream. O `PollWorker` existente continua como fallback — nenhuma modificação nele necessária.

**Tech Stack:** Rails 7.1, Turbo Streams, OpenSSL HMAC-SHA256, RSpec request specs, WebMock

---

### Task 1: Adicionar rota do webhook

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Adicionar bloco de rota**

Abrir `config/routes.rb` e adicionar antes do `get "up"`:

```ruby
# Webhooks externos — sem autenticação Devise, sem tenant
namespace :webhooks do
  post :heygen, to: "heygen#receive"
end
```

O arquivo final deve ter esta estrutura:

```ruby
Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations"
  }

  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end
  root to: redirect("/users/sign_in")

  get "dashboard", to: "dashboard#index", as: :dashboard

  resources :competitors, only: [ :index, :new, :create, :show, :destroy ] do
    resources :analyses, only: [ :new, :create, :show ]
  end

  resources :content_suggestions, only: [ :update ] do
    resources :generated_medias, only: [ :create ]
  end

  resources :playbooks do
    resources :playbook_versions, only: [ :index, :show ], shallow: true
    resources :playbook_feedbacks, only: [ :create, :update ], shallow: true do
      member do
        patch :incorporate
        patch :dismiss
      end
    end
    member do
      get :export
    end
  end

  namespace :settings do
    resource :api_keys, only: [ :show ], controller: "api_keys" do
      post   "providers/:provider", to: "api_keys#create",  as: :create_for
      patch  "providers/:provider", to: "api_keys#update",  as: :update_for
      delete "providers/:provider", to: "api_keys#destroy", as: :destroy_for
    end
    resource :llm_preferences, only: [ :edit, :update ]
    resource :media_generation, only: [ :show, :update ], controller: "media_generation" do
      post :validate_key, on: :collection
    end
  end

  # Webhooks externos — sem autenticação Devise, sem tenant
  namespace :webhooks do
    post :heygen, to: "heygen#receive"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  unless Rails.env.production?
    get "design-system", to: "design_system#index"
  end
end
```

- [ ] **Step 2: Verificar rota gerada**

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails routes | grep heygen
```

Saída esperada:
```
webhooks_heygen POST /webhooks/heygen(.:format) webhooks/heygen#receive
```

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat(webhook): adicionar rota POST /webhooks/heygen"
```

---

### Task 2: Escrever specs com TDD

**Files:**
- Create: `spec/requests/webhooks/heygen_spec.rb`

- [ ] **Step 1: Criar o arquivo de spec**

```ruby
# spec/requests/webhooks/heygen_spec.rb
require "rails_helper"

RSpec.describe "Webhooks::Heygen", type: :request, skip_tenant: true do
  let(:webhook_secret) { "test_webhook_secret_abc" }
  let(:account)        { create(:account) }
  let(:content_suggestion) { create(:content_suggestion, account: account) }
  let(:generated_media) do
    create(:generated_media, :processing,
      account: account,
      content_suggestion: content_suggestion,
      provider_job_id: "vid_abc123"
    )
  end

  around do |example|
    original = ENV["HEYGEN_WEBHOOK_SECRET"]
    ENV["HEYGEN_WEBHOOK_SECRET"] = webhook_secret
    example.run
    ENV["HEYGEN_WEBHOOK_SECRET"] = original
  end

  def sign(body, secret: webhook_secret)
    OpenSSL::HMAC.hexdigest("SHA256", secret, body)
  end

  def post_webhook(payload, secret: webhook_secret)
    body = payload.to_json
    post "/webhooks/heygen",
      params: body,
      headers: {
        "Content-Type" => "application/json",
        "X-Signature"  => sign(body, secret: secret)
      }
  end

  def completed_payload(video_id: "vid_abc123")
    {
      event_type: "video_status",
      event_data: {
        video_id: video_id,
        status: "completed",
        video_url: "https://resource.heygen.com/video/#{video_id}.mp4",
        error: nil
      }
    }
  end

  def failed_payload(video_id: "vid_abc123")
    {
      event_type: "video_status",
      event_data: {
        video_id: video_id,
        status: "failed",
        video_url: nil,
        error: "Avatar rendering failed"
      }
    }
  end

  # ─── Assinatura inválida ───────────────────────────────────────────────────

  describe "assinatura inválida" do
    it "retorna 401 e não altera o banco" do
      generated_media # materializa o registro

      body = completed_payload.to_json
      post "/webhooks/heygen",
        params: body,
        headers: {
          "Content-Type" => "application/json",
          "X-Signature"  => "assinatura_errada"
        }

      expect(response).to have_http_status(:unauthorized)
      expect(generated_media.reload.status).to eq("processing")
    end
  end

  # ─── Evento desconhecido ───────────────────────────────────────────────────

  describe "evento desconhecido" do
    it "retorna 200 sem efeito no banco" do
      generated_media # materializa o registro

      post_webhook({ event_type: "some_other_event", event_data: {} })

      expect(response).to have_http_status(:ok)
      expect(generated_media.reload.status).to eq("processing")
    end
  end

  # ─── video_id não encontrado ──────────────────────────────────────────────

  describe "video_id não encontrado" do
    it "retorna 200 sem efeito (log de warning esperado)" do
      post_webhook(completed_payload(video_id: "id_inexistente"))

      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Status completed ─────────────────────────────────────────────────────

  describe "status completed" do
    it "atualiza GeneratedMedia para completed com output_url e finished_at" do
      gm = generated_media

      post_webhook(completed_payload)

      expect(response).to have_http_status(:ok)
      gm.reload
      expect(gm.status).to eq("completed")
      expect(gm.output_url).to eq("https://resource.heygen.com/video/vid_abc123.mp4")
      expect(gm.finished_at).to be_present
    end

    it "cria MediaGenerationUsageLog" do
      gm = generated_media

      expect {
        post_webhook(completed_payload)
      }.to change(MediaGenerationUsageLog, :count).by(1)

      log = MediaGenerationUsageLog.last
      expect(log.generated_media).to eq(gm)
      expect(log.provider).to eq("heygen")
    end

    it "faz broadcast Turbo Stream para o target correto" do
      gm = generated_media

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "media_generation_#{gm.account_id}",
        target: "generated_media_#{gm.id}",
        partial: "generated_medias/status",
        locals: { generated_media: gm }
      )

      post_webhook(completed_payload)
    end
  end

  # ─── Status failed ────────────────────────────────────────────────────────

  describe "status failed" do
    it "atualiza GeneratedMedia para failed com error_message e finished_at" do
      gm = generated_media

      post_webhook(failed_payload)

      expect(response).to have_http_status(:ok)
      gm.reload
      expect(gm.status).to eq("failed")
      expect(gm.error_message).to eq("Avatar rendering failed")
      expect(gm.finished_at).to be_present
    end

    it "faz broadcast Turbo Stream" do
      gm = generated_media

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "media_generation_#{gm.account_id}",
        target: "generated_media_#{gm.id}",
        partial: "generated_medias/status",
        locals: { generated_media: gm }
      )

      post_webhook(failed_payload)
    end
  end

  # ─── Idempotência ─────────────────────────────────────────────────────────

  describe "idempotência" do
    it "ignora reentrada quando GeneratedMedia já está completed" do
      gm = create(:generated_media, :completed,
        account: account,
        content_suggestion: content_suggestion,
        provider_job_id: "vid_abc123"
      )

      expect(Turbo::StreamsChannel).not_to receive(:broadcast_replace_to)

      post_webhook(completed_payload)

      expect(response).to have_http_status(:ok)
      expect(gm.reload.status).to eq("completed")
    end
  end
end
```

- [ ] **Step 2: Rodar specs e confirmar falha por controller ausente**

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/requests/webhooks/heygen_spec.rb --format documentation 2>&1 | head -30
```

Saída esperada: todos os exemplos falhando com `ActionController::RoutingError` ou `uninitialized constant Webhooks::HeygenController`.

- [ ] **Step 3: Commit do spec antes de implementar**

```bash
git add spec/requests/webhooks/heygen_spec.rb
git commit -m "test(webhook): specs TDD para Webhooks::HeygenController"
```

---

### Task 3: Implementar o controller

**Files:**
- Create: `app/controllers/webhooks/heygen_controller.rb`

- [ ] **Step 1: Criar o diretório e o controller**

```ruby
# app/controllers/webhooks/heygen_controller.rb
module Webhooks
  class HeygenController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!
    skip_before_action :set_current_tenant

    before_action :read_raw_body
    before_action :verify_signature

    SIGNATURE_HEADER  = "X-Signature"
    VIDEO_STATUS_EVENT = "video_status"

    def receive
      unless event_type == VIDEO_STATUS_EVENT
        return head :ok
      end

      # Webhook não carrega tenant — busca global necessária para encontrar o registro
      generated_media = ActsAsTenant.without_tenant { GeneratedMedia.find_by(provider_job_id: video_id) }

      if generated_media.nil?
        Rails.logger.warn("[Webhooks::HeygenController] GeneratedMedia not found for video_id=#{video_id}")
        return head :ok
      end

      return head :ok if generated_media.completed? || generated_media.failed?

      ActsAsTenant.with_tenant(generated_media.account) do
        case video_status
        when "completed"
          generated_media.update!(
            status: :completed,
            output_url: event_data["video_url"],
            finished_at: Time.current
          )
          log_usage(generated_media)
          broadcast_update(generated_media)
        when "failed"
          generated_media.update!(
            status: :failed,
            error_message: event_data["error"] || "HeyGen generation failed",
            finished_at: Time.current
          )
          broadcast_update(generated_media)
        end
      end

      head :ok
    end

    private

    def read_raw_body
      @raw_body = request.body.tap(&:rewind).read
    end

    def verify_signature
      secret = ENV["HEYGEN_WEBHOOK_SECRET"]

      if secret.blank?
        Rails.logger.error("[Webhooks::HeygenController] HEYGEN_WEBHOOK_SECRET not configured")
        return head :internal_server_error
      end

      received = request.headers[SIGNATURE_HEADER].to_s
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, @raw_body)

      unless ActiveSupport::SecurityUtils.secure_compare(received, expected)
        head :unauthorized
      end
    end

    def payload
      @payload ||= JSON.parse(@raw_body)
    rescue JSON::ParserError
      {}
    end

    def event_type   = payload["event_type"]
    def event_data   = payload["event_data"] || {}
    def video_id     = event_data["video_id"]
    def video_status = event_data["status"]

    def log_usage(generated_media)
      MediaGenerationUsageLog.create!(
        account: generated_media.account,
        generated_media: generated_media,
        provider: "heygen",
        duration_seconds: generated_media.duration_seconds,
        cost_cents: 0
      )
    end

    def broadcast_update(generated_media)
      Turbo::StreamsChannel.broadcast_replace_to(
        "media_generation_#{generated_media.account_id}",
        target: "generated_media_#{generated_media.id}",
        partial: "generated_medias/status",
        locals: { generated_media: generated_media }
      )
    end
  end
end
```

- [ ] **Step 2: Rodar todos os specs do webhook**

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/requests/webhooks/heygen_spec.rb --format documentation
```

Saída esperada: todos os exemplos passando (green).

- [ ] **Step 3: Rodar a suite completa para checar regressões**

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec --format progress 2>&1 | tail -5
```

Saída esperada: sem novas falhas além das 3 pré-existentes (`playbook_feedback_spec` e `registrations_spec`).

- [ ] **Step 4: Commit**

```bash
git add app/controllers/webhooks/heygen_controller.rb
git commit -m "feat(webhook): implementar Webhooks::HeygenController com verificação HMAC"
```

---

### Task 4: Documentar variável de ambiente

**Files:**
- Modify: `.env.example`

- [ ] **Step 1: Adicionar entrada ao .env.example**

Adicionar ao final do arquivo `.env.example`:

```bash
# HeyGen Webhook
# Secret gerado no dashboard HeyGen ao cadastrar o endpoint do webhook.
# Dashboard: https://app.heygen.com/settings?nav=API → Webhooks
# ATENÇÃO: confirmar o nome exato do header de assinatura no dashboard
# (padrão usado no controller: X-Signature). Ajustar SIGNATURE_HEADER
# em app/controllers/webhooks/heygen_controller.rb se for diferente.
HEYGEN_WEBHOOK_SECRET=
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "chore: documentar HEYGEN_WEBHOOK_SECRET em .env.example"
```

---

### Task 5: Push e instruções de configuração no servidor

- [ ] **Step 1: Push para main**

```bash
git push origin main
```

- [ ] **Step 2: No servidor — pull e restart**

```bash
git pull && docker compose restart web
```

- [ ] **Step 3: No servidor — adicionar a variável de ambiente**

Editar `.env.production` (ou o arquivo de env equivalente) e adicionar:

```
HEYGEN_WEBHOOK_SECRET=<secret_copiado_do_dashboard_heygen>
```

Depois reiniciar para aplicar:

```bash
docker compose restart web
```

- [ ] **Step 4: Configurar o webhook no dashboard HeyGen**

1. Acessar https://app.heygen.com/settings?nav=API → seção Webhooks
2. Criar novo endpoint com URL: `https://viralspy.curt.com.br/webhooks/heygen`
3. Selecionar evento `video_status` (ou equivalente na UI)
4. Copiar o secret gerado e colocar em `HEYGEN_WEBHOOK_SECRET` no servidor
5. Confirmar o nome do header de assinatura — se diferente de `X-Signature`, alterar a constante `SIGNATURE_HEADER` em `app/controllers/webhooks/heygen_controller.rb`, commitar e fazer redeploy
