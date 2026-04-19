# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::BaseProvider do
  let(:subclass) do
    Class.new(described_class) do
      def transcribe(video_url:)
        "implemented"
      end

      def call_with_retry(&block)
        with_retry(&block)
      end

      def call_download(url)
        download_to_memory(url)
      end
    end
  end

  let(:provider) { subclass.new(api_key: "test-key") }

  describe "#initialize" do
    it "raises MissingApiKeyError when api_key is nil" do
      expect { described_class.new(api_key: nil) }.to raise_error(Transcription::MissingApiKeyError)
    end

    it "raises MissingApiKeyError when api_key is empty" do
      expect { described_class.new(api_key: "") }.to raise_error(Transcription::MissingApiKeyError)
    end

    it "initializes successfully with valid api_key" do
      expect { described_class.new(api_key: "key") }.not_to raise_error
    end
  end

  describe "#transcribe" do
    it "raises NotImplementedError on base class" do
      base = described_class.new(api_key: "key")
      expect { base.transcribe(video_url: "http://example.com/v.mp4") }.to raise_error(NotImplementedError)
    end
  end

  describe "#with_retry" do
    it "retries once on RateLimitError then raises" do
      attempts = 0
      expect {
        provider.call_with_retry do
          attempts += 1
          raise Transcription::RateLimitError, "slow"
        end
      }.to raise_error(Transcription::RateLimitError)
      expect(attempts).to eq(2)
    end

    it "retries once on TimeoutError then raises" do
      attempts = 0
      expect {
        provider.call_with_retry do
          attempts += 1
          raise Transcription::TimeoutError, "timeout"
        end
      }.to raise_error(Transcription::TimeoutError)
      expect(attempts).to eq(2)
    end

    it "does not retry on DownloadError" do
      attempts = 0
      expect {
        provider.call_with_retry do
          attempts += 1
          raise Transcription::DownloadError, "net error"
        end
      }.to raise_error(Transcription::DownloadError)
      expect(attempts).to eq(1)
    end

    it "succeeds on second attempt after RateLimitError" do
      attempts = 0
      result = provider.call_with_retry do
        attempts += 1
        raise Transcription::RateLimitError if attempts < 2

        "ok"
      end
      expect(result).to eq("ok")
    end
  end

  describe "#download_to_memory" do
    let(:video_url) { "https://cdn.instagram.com/video.mp4" }

    it "downloads file and returns StringIO" do
      stub_request(:get, video_url)
        .to_return(status: 200, body: "fake-mp4", headers: { "Content-Length" => "8" })

      io = provider.call_download(video_url)
      expect(io).to be_a(StringIO)
      io.rewind
      expect(io.read).to eq("fake-mp4")
    end

    it "raises FileTooLargeError when content exceeds 25MB" do
      big_body = "x" * (26 * 1024 * 1024)
      stub_request(:get, video_url).to_return(status: 200, body: big_body)

      expect {
        provider.call_download(video_url)
      }.to raise_error(Transcription::FileTooLargeError, /25/)
    end

    it "raises DownloadError on SocketError" do
      stub_request(:get, video_url).to_raise(SocketError.new("getaddrinfo failed"))

      expect {
        provider.call_download(video_url)
      }.to raise_error(Transcription::DownloadError, /Network error/)
    end

    it "raises DownloadError on connection refused" do
      stub_request(:get, video_url).to_raise(Errno::ECONNREFUSED.new("connection refused"))

      expect {
        provider.call_download(video_url)
      }.to raise_error(Transcription::DownloadError)
    end
  end
end
