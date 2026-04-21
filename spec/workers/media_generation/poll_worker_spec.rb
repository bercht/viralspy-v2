require "rails_helper"

RSpec.describe MediaGeneration::PollWorker, type: :worker do
  let(:account) { create(:account) }
  let(:suggestion) { create(:content_suggestion, account: account) }
  let(:status_url) { "https://api.heygen.com/v1/video.status.get" }

  around do |example|
    ActsAsTenant.with_tenant(account) { example.run }
  end

  before do
    allow(MediaGeneration::PollWorker).to receive(:perform_in)
    create(:api_credential, account: account, provider: "heygen",
           encrypted_api_key: "test_key", active: true)
  end

  let(:generated_media) { create(:generated_media, :processing, account: account, content_suggestion: suggestion) }

  def stub_heygen_status(status:, video_url: nil, error: nil)
    stub_request(:get, status_url)
      .with(query: { video_id: generated_media.provider_job_id })
      .to_return(
        status: 200,
        body: {
          data: {
            video_id: generated_media.provider_job_id,
            status: status,
            video_url: video_url,
            error: error
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe "#perform" do
    context "quando vídeo está completed" do
      before { stub_heygen_status(status: "completed", video_url: "https://heygen.com/video.mp4") }

      it "atualiza output_url e status" do
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        described_class.new.perform(generated_media.id)
        generated_media.reload
        expect(generated_media.completed?).to be true
        expect(generated_media.output_url).to eq("https://heygen.com/video.mp4")
      end

      it "cria MediaGenerationUsageLog" do
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        expect {
          described_class.new.perform(generated_media.id)
        }.to change(MediaGenerationUsageLog, :count).by(1)
      end

      it "chama broadcast_replace_to" do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "media_generation_#{account.id}",
          hash_including(target: "generated_media_#{generated_media.id}")
        )
        described_class.new.perform(generated_media.id)
      end
    end

    context "quando vídeo está failed" do
      before { stub_heygen_status(status: "failed", error: "Avatar not found") }

      it "atualiza status para failed com error_message" do
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        described_class.new.perform(generated_media.id)
        generated_media.reload
        expect(generated_media.failed?).to be true
        expect(generated_media.error_message).to eq("Avatar not found")
      end
    end

    context "quando status ainda é processing" do
      before { stub_heygen_status(status: "processing") }

      it "enfileira próxima iteração com attempt + 1" do
        described_class.new.perform(generated_media.id, 1)
        expect(MediaGeneration::PollWorker).to have_received(:perform_in).with(
          10.seconds, generated_media.id, 2
        )
      end
    end

    context "quando attempt > MAX_ATTEMPTS" do
      it "marca como failed com mensagem de timeout" do
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        described_class.new.perform(generated_media.id, described_class::MAX_ATTEMPTS + 1)
        generated_media.reload
        expect(generated_media.failed?).to be true
        expect(generated_media.error_message).to include("timeout")
      end
    end

    context "quando GeneratedMedia já está completed" do
      let(:completed_media) { create(:generated_media, :completed, account: account, content_suggestion: suggestion) }

      it "retorna sem fazer nada" do
        expect(Turbo::StreamsChannel).not_to receive(:broadcast_replace_to)
        described_class.new.perform(completed_media.id)
        completed_media.reload
        expect(completed_media.completed?).to be true
      end
    end

    context "quando chave HeyGen não encontrada" do
      before { account.api_credentials.find_by(provider: "heygen")&.destroy }

      it "marca como failed" do
        allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        described_class.new.perform(generated_media.id)
        generated_media.reload
        expect(generated_media.failed?).to be true
        expect(generated_media.error_message).to include("API key")
      end
    end
  end
end
