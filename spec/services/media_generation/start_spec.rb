require "rails_helper"

RSpec.describe MediaGeneration::Start do
  let(:account) { create(:account) }
  let(:suggestion) { create(:content_suggestion, account: account) }
  let(:generate_url) { "https://api.heygen.com/v2/video/generate" }

  around do |example|
    ActsAsTenant.with_tenant(account) { example.run }
  end

  before do
    allow(MediaGeneration::PollWorker).to receive(:perform_in)
    account.update!(media_generation_preferences: {
      "avatar_id" => "avatar_123",
      "voice_id" => "voice_pt_br"
    })
  end

  subject(:outcome) { described_class.call(content_suggestion: suggestion, account: account) }

  context "com chave HeyGen configurada e settings válidos" do
    before do
      create(:api_credential, account: account, provider: "heygen",
             encrypted_api_key: "test_heygen_key", active: true)

      stub_request(:post, generate_url)
        .to_return(
          status: 202,
          body: { code: 100, data: { video_id: "job_xyz" }, message: "success" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "retorna Outcome com success" do
      expect(outcome.success?).to be true
    end

    it "cria GeneratedMedia com status processing" do
      outcome
      media = GeneratedMedia.last
      expect(media.processing?).to be true
      expect(media.provider_job_id).to eq("job_xyz")
    end

    it "enfileira PollWorker" do
      outcome
      expect(MediaGeneration::PollWorker).to have_received(:perform_in).once
    end

    it "persiste o script enviado" do
      outcome
      expect(GeneratedMedia.last.prompt_sent).to be_present
    end
  end

  context "sem chave HeyGen configurada" do
    it "retorna Outcome com failure e error_code :missing_api_key" do
      expect(outcome.failure?).to be true
      expect(outcome.error_code).to eq(:missing_api_key)
    end

    it "não cria GeneratedMedia" do
      expect { outcome }.not_to change(GeneratedMedia, :count)
    end
  end

  context "sem avatar_id configurado" do
    before do
      create(:api_credential, account: account, provider: "heygen",
             encrypted_api_key: "test_key", active: true)
      account.update!(media_generation_preferences: { "voice_id" => "voice_pt_br" })
    end

    it "retorna failure com error_code :missing_settings" do
      expect(outcome.failure?).to be true
      expect(outcome.error_code).to eq(:missing_settings)
    end
  end

  context "quando HeyGen API retorna falha" do
    before do
      create(:api_credential, account: account, provider: "heygen",
             encrypted_api_key: "bad_key", active: true)

      stub_request(:post, generate_url)
        .to_return(status: 401,
                   body: { message: "Unauthorized" }.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "retorna failure" do
      expect(outcome.failure?).to be true
    end

    it "persiste GeneratedMedia com status failed" do
      outcome
      expect(GeneratedMedia.last.failed?).to be true
      expect(GeneratedMedia.last.error_message).to be_present
    end

    it "não enfileira PollWorker" do
      outcome
      expect(MediaGeneration::PollWorker).not_to have_received(:perform_in)
    end
  end
end
