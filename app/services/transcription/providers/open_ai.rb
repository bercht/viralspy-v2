# frozen_string_literal: true

module Transcription
  module Providers
    class OpenAI < Transcription::BaseProvider
      MODEL = "gpt-4o-mini-transcribe"
      API_URL = "https://api.openai.com/v1/audio/transcriptions"

      def initialize(api_key: ENV["OPENAI_API_KEY"])
        super(api_key: api_key)
      end

      def transcribe(video_url:)
        with_retry do
          video_io = download_to_memory(video_url)
          response = upload_and_transcribe(video_io)
          parse_success(response)
        end
      rescue Transcription::FileTooLargeError => e
        Transcription::Result.failure(error: e.message, error_code: :file_too_large)
      rescue Transcription::DownloadError => e
        Transcription::Result.failure(error: e.message, error_code: :download_failed)
      rescue Transcription::TimeoutError => e
        Transcription::Result.failure(error: e.message, error_code: :timeout)
      rescue Transcription::RateLimitError => e
        Transcription::Result.failure(error: e.message, error_code: :rate_limit)
      rescue Transcription::AuthenticationError => e
        Transcription::Result.failure(error: e.message, error_code: :auth)
      rescue Transcription::Error => e
        Transcription::Result.failure(error: e.message, error_code: :unknown)
      end

      private

      def upload_and_transcribe(video_io)
        temp = Tempfile.new([ "transcription_video", ".mp4" ], binmode: true)
        temp.write(video_io.read)
        temp.rewind

        response = HTTParty.post(
          API_URL,
          headers: { "Authorization" => "Bearer #{api_key}" },
          body: {
            model: MODEL,
            response_format: "verbose_json",
            file: temp
          },
          timeout: TOTAL_TIMEOUT
        )

        handle_http_response(response)
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        raise Transcription::TimeoutError, "API timeout: #{e.message}"
      rescue SocketError, Errno::ECONNREFUSED => e
        raise Transcription::DownloadError, "Network error: #{e.message}"
      ensure
        temp&.close
        temp&.unlink
      end

      def handle_http_response(response)
        case response.code
        when 200 then response
        when 429 then raise Transcription::RateLimitError, "Rate limit: #{response.body}"
        when 401 then raise Transcription::AuthenticationError, "Unauthorized: #{response.body}"
        when 413 then raise Transcription::FileTooLargeError, "Payload too large per API"
        when 400 then raise Transcription::Error, "Bad request: #{response.body}"
        when 500..599 then raise Transcription::Error, "Server error #{response.code}: #{response.body}"
        else raise Transcription::Error, "Unexpected status #{response.code}: #{response.body}"
        end
      end

      def parse_success(response)
        body = response.parsed_response
        body = JSON.parse(body) if body.is_a?(String)

        transcript = body["text"]
        raise Transcription::ResponseParseError, "No text in response" if transcript.nil?

        duration = body["duration"]&.to_f&.round

        Transcription::Result.success(transcript: transcript, duration_seconds: duration)
      rescue JSON::ParserError => e
        raise Transcription::ResponseParseError, "Invalid JSON: #{e.message}"
      end
    end
  end
end
