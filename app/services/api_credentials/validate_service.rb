# frozen_string_literal: true

module ApiCredentials
  class ValidateService
    TIMEOUT_SECONDS = 15

    def self.call(credential)
      new(credential).call
    end

    def initialize(credential)
      @credential = credential
    end

    def call
      result = validate_against_provider
      persist_status(result)
      result
    rescue StandardError => e
      Rails.logger.error("[ApiCredentials::ValidateService] Unexpected error for credential ##{credential.id}: #{e.class} - #{e.message}")
      result = Result.failure(status: :unknown, message: "Unexpected error: #{e.message}")
      begin
        persist_status(result)
      rescue StandardError => persist_error
        Rails.logger.error("[ApiCredentials::ValidateService] Could not persist status for credential ##{credential.id}: #{persist_error.message}")
      end
      result
    end

    private

    attr_reader :credential

    def validate_against_provider
      case credential.provider
      when "openai"     then validate_openai
      when "anthropic"  then validate_anthropic
      when "assemblyai" then validate_assemblyai
      else
        Result.failure(status: :unknown, message: "Unsupported provider: #{credential.provider}")
      end
    end

    def persist_status(result)
      credential.update!(
        last_validation_status: result.status,
        last_validated_at: Time.current
      )
    end

    # ----- OpenAI -----

    def validate_openai
      client = ::OpenAI::Client.new(
        access_token: credential.encrypted_api_key,
        request_timeout: TIMEOUT_SECONDS
      )
      client.models.list
      Result.success
    rescue Faraday::UnauthorizedError, ::OpenAI::Error => e
      interpret_openai_error(e)
    rescue Faraday::TooManyRequestsError
      Result.failure(status: :quota_exceeded, message: "OpenAI rate limit or quota exceeded")
    rescue Faraday::TimeoutError, Net::ReadTimeout, Net::OpenTimeout
      Result.failure(status: :unknown, message: "OpenAI timed out — try again")
    rescue Faraday::Error => e
      Result.failure(status: :unknown, message: "OpenAI connection error: #{e.message}")
    end

    def interpret_openai_error(error)
      message = error.message.to_s.downcase
      if message.include?("401") || message.include?("unauthorized") || message.include?("invalid api key") || message.include?("incorrect api key")
        Result.failure(status: :failed, message: "OpenAI rejected the API key (invalid or revoked)")
      elsif message.include?("429") || message.include?("quota") || message.include?("rate limit") || message.include?("insufficient")
        Result.failure(status: :quota_exceeded, message: "OpenAI quota exceeded or rate-limited")
      else
        Result.failure(status: :unknown, message: "OpenAI error: #{error.message}")
      end
    end

    # ----- Anthropic -----

    def validate_anthropic
      client = ::Anthropic::Client.new(
        api_key: credential.encrypted_api_key,
        timeout: TIMEOUT_SECONDS,
        max_retries: 0
      )
      client.messages.create(
        model: "claude-3-5-haiku-latest",
        max_tokens: 1,
        messages: [ { role: "user", content: "hi" } ]
      )
      Result.success
    rescue ::Anthropic::Errors::AuthenticationError => e
      Result.failure(status: :failed, message: "Anthropic rejected the API key: #{e.message}")
    rescue ::Anthropic::Errors::RateLimitError => e
      Result.failure(status: :quota_exceeded, message: "Anthropic rate limit or quota exceeded: #{e.message}")
    rescue ::Anthropic::Errors::APITimeoutError, ::Anthropic::Errors::APIConnectionError => e
      Result.failure(status: :unknown, message: "Anthropic connection timed out: #{e.message}")
    rescue ::Anthropic::Errors::APIStatusError => e
      Result.failure(status: :unknown, message: "Anthropic error: #{e.message}")
    end

    # ----- AssemblyAI -----

    def validate_assemblyai
      client = ::AssemblyAI::Client.new(api_key: credential.encrypted_api_key)
      client.transcripts.list(limit: 1)
      Result.success
    rescue StandardError => e
      interpret_assemblyai_error(e)
    end

    def interpret_assemblyai_error(error)
      message = error.message.to_s.downcase

      if message.include?("401") || message.include?("unauthorized") || message.include?("invalid api key")
        Result.failure(status: :failed, message: "AssemblyAI rejected the API key: #{error.message}")
      elsif message.include?("429") || message.include?("rate limit") || message.include?("quota")
        Result.failure(status: :quota_exceeded, message: "AssemblyAI rate limit or quota exceeded")
      elsif message.include?("timeout") || message.include?("timed out")
        Result.failure(status: :unknown, message: "AssemblyAI timed out: #{error.message}")
      else
        Result.failure(status: :unknown, message: "AssemblyAI error: #{error.message}")
      end
    end
  end
end
