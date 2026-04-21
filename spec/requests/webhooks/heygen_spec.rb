# spec/requests/webhooks/heygen_spec.rb
require "rails_helper"

RSpec.describe "Webhooks::Heygen", type: :request, skip_tenant: true do
  let(:webhook_secret) { "test_webhook_secret_abc" }

  let(:account) do
    ActsAsTenant.without_tenant { create(:account) }
  end

  let(:content_suggestion) do
    ActsAsTenant.with_tenant(account) { create(:content_suggestion, account: account) }
  end

  let(:generated_media) do
    ActsAsTenant.with_tenant(account) do
      create(:generated_media, :processing,
        account: account,
        content_suggestion: content_suggestion,
        provider_job_id: "vid_abc123"
      )
    end
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

      initial_count = ActsAsTenant.with_tenant(account) { MediaGenerationUsageLog.count }

      post_webhook(completed_payload)

      final_count = ActsAsTenant.with_tenant(account) { MediaGenerationUsageLog.count }
      expect(final_count).to eq(initial_count + 1)

      log = ActsAsTenant.with_tenant(account) { MediaGenerationUsageLog.last }
      expect(ActsAsTenant.with_tenant(account) { log.generated_media }).to eq(gm)
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

  # ─── Secret não configurado ───────────────────────────────────────────────

  describe "secret não configurado" do
    around do |example|
      original = ENV.delete("HEYGEN_WEBHOOK_SECRET")
      example.run
      ENV["HEYGEN_WEBHOOK_SECRET"] = original
    end

    it "retorna 500 sem alterar o banco" do
      generated_media

      body = completed_payload.to_json
      post "/webhooks/heygen",
        params: body,
        headers: {
          "Content-Type" => "application/json",
          "X-Signature"  => "qualquer_coisa"
        }

      expect(response).to have_http_status(:internal_server_error)
      expect(generated_media.reload.status).to eq("processing")
    end
  end

  # ─── Idempotência ─────────────────────────────────────────────────────────

  describe "idempotência" do
    it "ignora reentrada quando GeneratedMedia já está completed" do
      gm = ActsAsTenant.with_tenant(account) do
        create(:generated_media, :completed,
          account: account,
          content_suggestion: content_suggestion,
          provider_job_id: "vid_abc123"
        )
      end

      expect(Turbo::StreamsChannel).not_to receive(:broadcast_replace_to)

      post_webhook(completed_payload)

      expect(response).to have_http_status(:ok)
      expect(gm.reload.status).to eq("completed")
    end
  end
end
