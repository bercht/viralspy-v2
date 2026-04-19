# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::Providers::AssemblyAI do
  let(:api_key) { "test_assemblyai_key" }
  let(:video_url) { "https://instagram.com/video.mp4" }
  let(:provider) { described_class.new(api_key: api_key) }

  describe "#initialize" do
    it "raises MissingApiKeyError when api_key is nil" do
      expect { described_class.new(api_key: nil) }.to raise_error(Transcription::MissingApiKeyError)
    end

    it "raises MissingApiKeyError when api_key is empty" do
      expect { described_class.new(api_key: "") }.to raise_error(Transcription::MissingApiKeyError)
    end
  end

  describe "#transcribe" do
    let(:upload_url) { "https://cdn.assemblyai.com/upload/abc123" }
    let(:uploaded_double) { instance_double("AssemblyAI::Files::UploadedFile", upload_url: upload_url) }
    let(:completed_transcript) do
      instance_double(
        "AssemblyAI::Transcripts::Transcript",
        text: "Olá pessoal, hoje vou falar sobre três erros...",
        audio_duration: 42,
        status: "completed",
        error: nil
      )
    end

    let(:files_api)       { instance_double("AssemblyAI::Files::Client") }
    let(:transcripts_api) { instance_double("AssemblyAI::Transcripts::Client") }
    let(:client)          { instance_double("AssemblyAI::Client", files: files_api, transcripts: transcripts_api) }

    before do
      allow(::AssemblyAI::Client).to receive(:new).with(api_key: api_key).and_return(client)

      stub_request(:get, video_url).to_return(
        status: 200,
        body: "fake_mp4_bytes",
        headers: { "Content-Type" => "video/mp4" }
      )
    end

    context "success" do
      before do
        allow(files_api).to receive(:upload).and_return(uploaded_double)
        allow(transcripts_api).to receive(:transcribe)
          .with(audio_url: upload_url)
          .and_return(completed_transcript)
      end

      it "returns Result.success with transcript and duration" do
        result = provider.transcribe(video_url: video_url)

        expect(result).to be_success
        expect(result.transcript).to include("Olá pessoal")
        expect(result.duration_seconds).to eq(42)
      end

      it "uploads file and transcribes via upload_url" do
        provider.transcribe(video_url: video_url)

        expect(files_api).to have_received(:upload).once
        expect(transcripts_api).to have_received(:transcribe).with(audio_url: upload_url)
      end
    end

    context "when transcript returns with error status" do
      before do
        allow(files_api).to receive(:upload).and_return(uploaded_double)
        allow(transcripts_api).to receive(:transcribe).and_return(
          instance_double(
            "AssemblyAI::Transcripts::Transcript",
            text: nil,
            audio_duration: nil,
            status: "error",
            error: "Invalid audio file"
          )
        )
      end

      it "returns Result.failure with :unknown error_code" do
        result = provider.transcribe(video_url: video_url)

        expect(result).to be_failure
        expect(result.error_code).to eq(:unknown)
        expect(result.error).to include("AssemblyAI transcript error")
      end
    end

    context "when SDK raises rate limit" do
      before do
        allow(files_api).to receive(:upload).and_return(uploaded_double)
        allow(transcripts_api).to receive(:transcribe)
          .and_raise(StandardError.new("Rate limit exceeded (429)"))
      end

      it "retries once and returns :rate_limit if retries exhausted" do
        result = provider.transcribe(video_url: video_url)

        expect(result).to be_failure
        expect(result.error_code).to eq(:rate_limit)
        expect(transcripts_api).to have_received(:transcribe).twice
      end
    end

    context "when SDK raises unauthorized during upload" do
      before do
        allow(files_api).to receive(:upload)
          .and_raise(StandardError.new("Unauthorized: invalid API key"))
      end

      it "returns Result.failure with :auth (no retry)" do
        result = provider.transcribe(video_url: video_url)

        expect(result).to be_failure
        expect(result.error_code).to eq(:auth)
        expect(files_api).to have_received(:upload).once
      end
    end

    context "when download exceeds 25MB" do
      before do
        big_body = "x" * (26 * 1024 * 1024)
        stub_request(:get, video_url).to_return(status: 200, body: big_body)
      end

      it "returns Result.failure with :file_too_large" do
        result = provider.transcribe(video_url: video_url)

        expect(result).to be_failure
        expect(result.error_code).to eq(:file_too_large)
      end
    end

    context "when transcript text is empty" do
      before do
        allow(files_api).to receive(:upload).and_return(uploaded_double)
        allow(transcripts_api).to receive(:transcribe).and_return(
          instance_double(
            "AssemblyAI::Transcripts::Transcript",
            text: "",
            audio_duration: 10,
            status: "completed",
            error: nil
          )
        )
      end

      it "returns Result.failure with :unknown (ResponseParseError)" do
        result = provider.transcribe(video_url: video_url)

        expect(result).to be_failure
        expect(result.error_code).to eq(:unknown)
      end
    end
  end
end
