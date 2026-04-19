# frozen_string_literal: true

module Transcription
  module Providers
    class AssemblyAI < Transcription::BaseProvider
      # Modelo "best" (Slam-1/Universal) é o default da gem assemblyai.
      # ~US$ 0.12/hora de áudio. Reel típico (~40s) custa ~US$ 0.0013.

      def initialize(api_key: ENV["ASSEMBLYAI_API_KEY"])
        super(api_key: api_key)
      end

      def transcribe(video_url:)
        with_retry do
          video_io = download_to_memory(video_url)
          uploaded_url = upload_file(video_io)
          transcript_obj = submit_and_wait(uploaded_url)
          parse_success(transcript_obj)
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

      def client
        @client ||= ::AssemblyAI::Client.new(api_key: api_key)
      end

      def upload_file(video_io)
        uploaded = client.files.upload(file: video_io)
        uploaded.upload_url
      rescue StandardError => e
        classify_sdk_error!(e, context: "upload")
      end

      def submit_and_wait(audio_url)
        transcript = client.transcripts.transcribe(audio_url: audio_url)

        if transcript.status.to_s == "error"
          raise Transcription::Error, "AssemblyAI transcript error: #{transcript.error}"
        end

        transcript
      rescue Transcription::Error
        raise
      rescue StandardError => e
        classify_sdk_error!(e, context: "transcribe")
      end

      def parse_success(transcript_obj)
        text = transcript_obj.text
        raise Transcription::ResponseParseError, "No text in response" if text.nil? || text.strip.empty?

        duration = transcript_obj.audio_duration&.to_i

        Transcription::Result.success(transcript: text, duration_seconds: duration)
      end

      def classify_sdk_error!(error, context:)
        msg = error.message.to_s.downcase

        case
        when msg.include?("rate limit") || msg.include?("429")
          raise Transcription::RateLimitError, "Rate limit (#{context}): #{error.message}"
        when msg.include?("unauthorized") || msg.include?("401") || msg.include?("invalid api key")
          raise Transcription::AuthenticationError, "Unauthorized (#{context}): #{error.message}"
        when msg.include?("timeout") || msg.include?("timed out")
          raise Transcription::TimeoutError, "Timeout (#{context}): #{error.message}"
        when msg.include?("payload too large") || msg.include?("413")
          raise Transcription::FileTooLargeError, "File too large per API (#{context})"
        when error.is_a?(::Transcription::Error)
          raise error
        else
          raise Transcription::Error, "AssemblyAI error (#{context}): #{error.class} - #{error.message}"
        end
      end
    end
  end
end
