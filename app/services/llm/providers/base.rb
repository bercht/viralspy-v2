# frozen_string_literal: true

module LLM
  module Providers
    class Base
      DEFAULT_TIMEOUT = 60
      DEFAULT_MAX_TOKENS = 2000

      def initialize(api_key:, timeout: DEFAULT_TIMEOUT)
        raise LLM::MissingApiKeyError, "API key is required" if api_key.blank?

        @api_key = api_key
        @timeout = timeout
      end

      def complete(model:, messages:, system: nil, json_mode: false, temperature: 0.7, max_tokens: DEFAULT_MAX_TOKENS)
        raise NotImplementedError, "#{self.class} must implement #complete"
      end

      protected

      attr_reader :api_key, :timeout

      def with_retry(max_attempts: 3)
        attempt = 0
        begin
          attempt += 1
          yield
        rescue LLM::RateLimitError, LLM::TimeoutError => e
          raise if attempt >= max_attempts

          sleep_duration = [ 1, 4 ].at(attempt - 1) || 4
          Rails.logger.warn("[LLM] Retry #{attempt}/#{max_attempts - 1}: #{e.class} - #{e.message}")
          sleep(sleep_duration) unless Rails.env.test?
          retry
        end
      end
    end
  end
end
