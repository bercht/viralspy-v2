# frozen_string_literal: true

module Transcription
  class BaseProvider
    DOWNLOAD_TIMEOUT = 30
    TOTAL_TIMEOUT = 120
    MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024

    def initialize(api_key:)
      raise Transcription::MissingApiKeyError, "API key is required" if api_key.blank?

      @api_key = api_key
    end

    def transcribe(video_url:)
      raise NotImplementedError, "#{self.class} must implement #transcribe"
    end

    protected

    attr_reader :api_key

    def with_retry(max_attempts: 2)
      attempt = 0
      begin
        attempt += 1
        yield
      rescue Transcription::RateLimitError, Transcription::TimeoutError => e
        raise if attempt >= max_attempts

        Rails.logger.warn("[Transcription] Retry #{attempt}/#{max_attempts - 1}: #{e.class} - #{e.message}")
        sleep(3) unless Rails.env.test?
        retry
      end
    end

    def download_to_memory(video_url)
      buffer = StringIO.new
      bytes_downloaded = 0

      HTTParty.get(
        video_url,
        timeout: DOWNLOAD_TIMEOUT,
        stream_body: true
      ) do |fragment|
        bytes_downloaded += fragment.bytesize
        if bytes_downloaded > MAX_FILE_SIZE_BYTES
          raise Transcription::FileTooLargeError,
                "File exceeds 25MB limit (got #{bytes_downloaded} bytes)"
        end
        buffer.write(fragment)
      end

      buffer.rewind
      buffer
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      raise Transcription::TimeoutError, "Download timeout: #{e.message}"
    rescue HTTParty::ResponseError => e
      raise Transcription::DownloadError, "Download failed: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      raise Transcription::DownloadError, "Network error: #{e.message}"
    end
  end
end
