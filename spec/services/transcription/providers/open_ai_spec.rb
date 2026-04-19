# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::Providers::OpenAI do
  let(:provider) { described_class.new(api_key: "test-key") }
  let(:video_url) { "https://cdn.instagram.com/video.mp4" }
  let(:success_api_body) do
    {
      text: "Hello world, this is a transcription",
      language: "en",
      duration: 42.3,
      segments: []
    }.to_json
  end

  describe "#initialize" do
    it "raises MissingApiKeyError without api_key" do
      expect { described_class.new(api_key: nil) }.to raise_error(Transcription::MissingApiKeyError)
    end
  end

  describe "#transcribe" do
    context "success path" do
      before do
        stub_request(:get, video_url)
          .to_return(status: 200, body: "fake-mp4-content", headers: { "Content-Length" => "16" })

        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: success_api_body,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success result with transcript and duration" do
        result = provider.transcribe(video_url: video_url)

        expect(result).to be_success
        expect(result.transcript).to eq("Hello world, this is a transcription")
        expect(result.duration_seconds).to eq(42)
      end
    end

    context "file too large" do
      before do
        stub_request(:get, video_url)
          .to_return(status: 200, body: "x" * (26 * 1024 * 1024))
      end

      it "returns failure with :file_too_large code" do
        result = provider.transcribe(video_url: video_url)
        expect(result).to be_failure
        expect(result.error_code).to eq(:file_too_large)
      end
    end

    context "download network error" do
      before do
        stub_request(:get, video_url).to_raise(SocketError.new("getaddrinfo failed"))
      end

      it "returns failure with :download_failed code" do
        result = provider.transcribe(video_url: video_url)
        expect(result).to be_failure
        expect(result.error_code).to eq(:download_failed)
      end
    end

    context "API returns 429" do
      before do
        stub_request(:get, video_url)
          .to_return(status: 200, body: "fake-mp4", headers: {})
      end

      it "retries once and succeeds on second attempt" do
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            { status: 429, body: '{"error":{"message":"Rate limit exceeded"}}', headers: { "Content-Type" => "application/json" } },
            { status: 200, body: success_api_body, headers: { "Content-Type" => "application/json" } }
          )

        result = provider.transcribe(video_url: video_url)
        expect(result).to be_success
      end

      it "returns failure after all retries exhausted" do
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 429, body: '{"error":{"message":"Rate limit"}}',
            headers: { "Content-Type" => "application/json" }
          ).times(2)

        result = provider.transcribe(video_url: video_url)
        expect(result).to be_failure
        expect(result.error_code).to eq(:rate_limit)
      end
    end

    context "API returns 401" do
      before do
        stub_request(:get, video_url)
          .to_return(status: 200, body: "fake-mp4", headers: {})
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(status: 401, body: '{"error":{"message":"Unauthorized"}}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns failure with :auth code" do
        result = provider.transcribe(video_url: video_url)
        expect(result).to be_failure
        expect(result.error_code).to eq(:auth)
      end
    end

    context "API returns invalid JSON" do
      before do
        stub_request(:get, video_url)
          .to_return(status: 200, body: "fake-mp4", headers: {})
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(status: 200, body: "this is not json",
                     headers: { "Content-Type" => "text/plain" })
      end

      it "returns failure with :unknown code" do
        result = provider.transcribe(video_url: video_url)
        expect(result).to be_failure
        expect(result.error_code).to eq(:unknown)
      end
    end

    context "API response missing text field" do
      before do
        stub_request(:get, video_url)
          .to_return(status: 200, body: "fake-mp4", headers: {})
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(status: 200, body: '{"duration": 10}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns failure with :unknown code" do
        result = provider.transcribe(video_url: video_url)
        expect(result).to be_failure
        expect(result.error_code).to eq(:unknown)
      end
    end
  end
end
