# frozen_string_literal: true

module LLM
  module Providers
    class Anthropic < Base
      def initialize(api_key: ENV["ANTHROPIC_API_KEY"], timeout: DEFAULT_TIMEOUT)
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
          messages: normalize_messages(messages),
          max_tokens: max_tokens,
          temperature: temperature
        }

        system_prompt = build_system(system, json_mode)
        params[:system] = system_prompt if system_prompt.present?

        raw = client.messages.create(**params)
        parse_response(raw, model: model)
      rescue ::Anthropic::Errors::RateLimitError => e
        raise LLM::RateLimitError, e.message
      rescue ::Anthropic::Errors::APITimeoutError, ::Anthropic::Errors::APIConnectionError => e
        raise LLM::TimeoutError, e.message
      rescue ::Anthropic::Errors::AuthenticationError => e
        raise LLM::AuthenticationError, e.message
      rescue ::Anthropic::Errors::BadRequestError => e
        raise LLM::InvalidRequestError, e.message
      rescue ::Anthropic::Errors::NotFoundError => e
        raise LLM::ModelNotFoundError, e.message
      rescue ::Anthropic::Errors::APIStatusError => e
        raise LLM::Error, e.message
      end

      def client
        @client ||= ::Anthropic::Client.new(
          api_key: api_key,
          timeout: timeout,
          max_retries: 0
        )
      end

      def normalize_messages(messages)
        messages.reject { |m| m[:role].to_s == "system" || m["role"].to_s == "system" }
      end

      def build_system(system, json_mode)
        base = system.to_s
        return base unless json_mode

        json_instruction = "\n\nYou MUST respond with valid JSON only. Do not include markdown code fences, explanations, or any text outside the JSON object."
        (base + json_instruction).strip
      end

      def parse_response(raw, model:)
        text_block = raw.content.find { |b| b.type.to_s == "text" }
        raise LLM::ResponseParseError, "No text block in content" unless text_block

        LLM::Response.new(
          content: text_block.text,
          raw: raw,
          usage: {
            prompt_tokens: raw.usage.input_tokens,
            completion_tokens: raw.usage.output_tokens
          },
          model: model,
          provider: :anthropic,
          finish_reason: raw.stop_reason&.to_s
        )
      end
    end
  end
end
