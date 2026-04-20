# frozen_string_literal: true

module LLM
  module Providers
    class OpenAI < Base
      def initialize(api_key:, timeout: DEFAULT_TIMEOUT)
        super(api_key: api_key, timeout: timeout)
      end

      def complete(model:, messages:, system: nil, json_mode: false, temperature: 0.7, max_tokens: DEFAULT_MAX_TOKENS)
        with_retry do
          call_api(model: model, messages: messages, system: system, json_mode: json_mode,
                   temperature: temperature, max_tokens: max_tokens)
        end
      end

      private

      def call_api(model:, messages:, system:, json_mode:, temperature:, max_tokens:)
        params = {
          model: model,
          messages: build_messages(messages, system),
          temperature: temperature,
          max_tokens: max_tokens
        }
        params[:response_format] = { type: "json_object" } if json_mode

        raw = client.chat(parameters: params)
        parse_response(raw, model: model)
      rescue ::OpenAI::Error, Faraday::Error => e
        handle_api_error(e)
      rescue Faraday::TimeoutError, Net::ReadTimeout, Net::OpenTimeout => e
        raise LLM::TimeoutError, e.message
      end

      def client
        @client ||= ::OpenAI::Client.new(
          access_token: api_key,
          request_timeout: timeout
        )
      end

      def build_messages(messages, system)
        return messages unless system.present?

        [ { role: "system", content: system } ] + messages
      end

      def parse_response(raw, model:)
        raise LLM::ResponseParseError, "Empty response" if raw.blank?

        choice = raw.dig("choices", 0)
        raise LLM::ResponseParseError, "No choices in response" unless choice

        content = choice.dig("message", "content")
        raise LLM::ResponseParseError, "No content in message" if content.nil?

        usage = raw["usage"] || {}

        LLM::Response.new(
          content: content,
          raw: raw,
          usage: {
            prompt_tokens: usage["prompt_tokens"] || 0,
            completion_tokens: usage["completion_tokens"] || 0
          },
          model: model,
          provider: :openai,
          finish_reason: choice["finish_reason"]
        )
      end

      def handle_api_error(error)
        status = error.respond_to?(:response) && error.response.is_a?(Hash) ? error.response[:status] : nil
        message = error.message.to_s.downcase

        case status || message
        when 429, /rate limit/, /429/
          raise LLM::RateLimitError, error.message
        when 401, /unauthorized/, /invalid.*api.*key/, /401/
          raise LLM::AuthenticationError, error.message
        when 404, /model.*not.*found/, /does not exist/
          raise LLM::ModelNotFoundError, error.message
        when 400, /invalid/, /bad request/, /400/
          raise LLM::InvalidRequestError, error.message
        when /timeout/, /timed out/
          raise LLM::TimeoutError, error.message
        else
          raise LLM::Error, error.message
        end
      end
    end
  end
end
