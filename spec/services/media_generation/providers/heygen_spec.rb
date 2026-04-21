require "rails_helper"

RSpec.describe MediaGeneration::Providers::Heygen do
  let(:api_key) { "test_heygen_key" }
  let(:provider) { described_class.new(api_key: api_key) }
  let(:generate_url) { "https://api.heygen.com/v2/video/generate" }
  let(:status_url) { "https://api.heygen.com/v1/video.status.get" }
  let(:user_info_url) { "https://api.heygen.com/v2/voices" }

  describe "#start_generation" do
    subject(:result) do
      provider.start_generation(
        script: "Olá! Este é um teste.",
        avatar_id: "avatar_123",
        voice_id: "voice_456",
        title: "Teste"
      )
    end

    context "quando HeyGen retorna 202 com video_id" do
      before do
        stub_request(:post, generate_url)
          .to_return(
            status: 202,
            body: { code: 100, data: { video_id: "job_abc123" }, message: "success" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retorna Result com success e job_id" do
        expect(result.success?).to be true
        expect(result.job_id).to eq("job_abc123")
        expect(result.status).to eq("pending")
      end
    end

    context "quando HeyGen retorna 200 com video_id" do
      before do
        stub_request(:post, generate_url)
          .to_return(
            status: 200,
            body: { code: 100, data: { video_id: "job_200" }, message: "success" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "também retorna success" do
        expect(result.success?).to be true
        expect(result.job_id).to eq("job_200")
      end
    end

    context "quando HeyGen retorna 401" do
      before do
        stub_request(:post, generate_url)
          .to_return(status: 401, body: { message: "Unauthorized" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "retorna failure com error_code :invalid_api_key" do
        expect(result.failure?).to be true
        expect(result.error_code).to eq(:invalid_api_key)
      end
    end

    context "quando HeyGen retorna 429" do
      before do
        stub_request(:post, generate_url)
          .to_return(status: 429, body: { message: "Too Many Requests" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "retorna failure com error_code :rate_limit" do
        expect(result.failure?).to be true
        expect(result.error_code).to eq(:rate_limit)
      end
    end

    context "quando HeyGen retorna 500" do
      before do
        stub_request(:post, generate_url)
          .to_return(status: 500, body: { message: "Internal error" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "retorna failure com error_code :generation_failed" do
        expect(result.failure?).to be true
        expect(result.error_code).to eq(:generation_failed)
      end
    end

    context "quando ocorre timeout" do
      before do
        stub_request(:post, generate_url).to_timeout
      end

      it "retorna failure com error_code :timeout" do
        expect(result.failure?).to be true
        expect(result.error_code).to eq(:timeout)
      end
    end
  end

  describe "#check_status" do
    subject(:result) { provider.check_status(job_id: "job_abc123") }

    context "quando vídeo está processing" do
      before do
        stub_request(:get, status_url)
          .with(query: { video_id: "job_abc123" })
          .to_return(
            status: 200,
            body: { data: { video_id: "job_abc123", status: "processing",
                            video_url: nil } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retorna success com status processing" do
        expect(result.success?).to be true
        expect(result.status).to eq("processing")
        expect(result.output_url).to be_nil
      end
    end

    context "quando vídeo está completed" do
      before do
        stub_request(:get, status_url)
          .with(query: { video_id: "job_abc123" })
          .to_return(
            status: 200,
            body: { data: { video_id: "job_abc123", status: "completed",
                            video_url: "https://resource.heygen.com/video/abc123.mp4" } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retorna success com output_url preenchido" do
        expect(result.success?).to be true
        expect(result.status).to eq("completed")
        expect(result.output_url).to eq("https://resource.heygen.com/video/abc123.mp4")
      end
    end

    context "quando vídeo está failed" do
      before do
        stub_request(:get, status_url)
          .with(query: { video_id: "job_abc123" })
          .to_return(
            status: 200,
            body: { data: { video_id: "job_abc123", status: "failed",
                            error: "Avatar not found" } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retorna failure com error_code :generation_failed" do
        expect(result.failure?).to be true
        expect(result.error_code).to eq(:generation_failed)
        expect(result.error).to eq("Avatar not found")
      end
    end

    context "quando retorna 401" do
      before do
        stub_request(:get, status_url)
          .with(query: { video_id: "job_abc123" })
          .to_return(status: 401, body: {}.to_json)
      end

      it "retorna failure com error_code :invalid_api_key" do
        expect(result.failure?).to be true
        expect(result.error_code).to eq(:invalid_api_key)
      end
    end
  end

  describe "#validate_api_key" do
    context "quando retorna 200" do
      before do
        stub_request(:get, user_info_url).to_return(status: 200, body: {}.to_json)
      end

      it "retorna true" do
        expect(provider.validate_api_key).to be true
      end
    end

    context "quando retorna 401" do
      before do
        stub_request(:get, user_info_url).to_return(status: 401, body: {}.to_json)
      end

      it "retorna false" do
        expect(provider.validate_api_key).to be false
      end
    end
  end

  describe "#fetch_avatars" do
    let(:avatars_url) { "https://api.heygen.com/v3/avatars/looks" }

    context "quando API retorna 200 com lista" do
      before do
        stub_request(:get, avatars_url)
          .to_return(
            status: 200,
            body: {
              data: [
                { "id" => "avatar_1", "name" => "Avatar Um", "preferred_orientation" => "horizontal", "preview_image_url" => "https://example.com/1.jpg" },
                { "id" => "avatar_2", "name" => "Avatar Dois", "preferred_orientation" => "vertical", "preview_image_url" => "https://example.com/2.jpg" }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retorna lista mapeada de avatares" do
        result = provider.fetch_avatars
        expect(result[:avatars].length).to eq(2)
        expect(result[:avatars].first).to include(id: "avatar_1", name: "Avatar Um (horizontal)")
      end
    end

    context "quando API retorna erro" do
      before do
        stub_request(:get, avatars_url).to_return(status: 500, body: {}.to_json)
      end

      it "retorna avatars vazio" do
        result = provider.fetch_avatars
        expect(result[:avatars]).to eq([])
      end
    end
  end

  describe "#fetch_voices" do
    let(:voices_url) { "https://api.heygen.com/v3/voices" }

    context "quando API retorna 200 com vozes" do
      before do
        stub_request(:get, voices_url)
          .to_return(
            status: 200,
            body: {
              data: {
                voices: [
                  { "voice_id" => "voice_pt_1", "display_name" => "Voz PT 1", "language" => "pt-BR" },
                  { "voice_id" => "voice_en_1", "display_name" => "Voice EN 1", "language" => "en-US" },
                  { "voice_id" => "voice_pt_2", "display_name" => "Voz PT 2", "language" => "pt" }
                ]
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "filtra apenas vozes pt-BR/pt" do
        result = provider.fetch_voices
        expect(result[:voices].map { |v| v[:id] }).to contain_exactly("voice_pt_1", "voice_pt_2")
      end

      it "mapeia voice_id para id" do
        result = provider.fetch_voices
        expect(result[:voices].first).to include(id: "voice_pt_1", name: "Voz PT 1")
      end
    end

    context "quando API retorna erro" do
      before do
        stub_request(:get, voices_url).to_return(status: 500, body: {}.to_json)
      end

      it "retorna voices vazio" do
        result = provider.fetch_voices
        expect(result[:voices]).to eq([])
      end
    end
  end
end
