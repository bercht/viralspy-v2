# frozen_string_literal: true

module LLM
  class Gateway
    SUPPORTED_PROVIDERS = %i[openai anthropic].freeze

    def self.complete(provider:, model:, messages:, use_case:, account:, api_key:,
                      system: nil, json_mode: false, temperature: 0.7,
                      max_tokens: Providers::Base::DEFAULT_MAX_TOKENS,
                      analysis: nil)
      validate_args!(provider: provider, use_case: use_case, account: account)
      raise LLM::MissingApiKeyError, "API key is required for provider #{provider}" if api_key.blank?

      provider_instance = build_provider(provider, api_key: api_key)
      response = provider_instance.complete(
        model: model,
        messages: messages,
        system: system,
        json_mode: json_mode,
        temperature: temperature,
        max_tokens: max_tokens
      )

      UsageLogger.log(response: response, account: account, use_case: use_case, analysis: analysis)

      response
    end

    def self.validate_args!(provider:, use_case:, account:)
      unless SUPPORTED_PROVIDERS.include?(provider)
        raise ProviderNotFoundError, "Unsupported provider: #{provider.inspect}. Supported: #{SUPPORTED_PROVIDERS.inspect}"
      end

      raise ArgumentError, "use_case is required and cannot be blank" if use_case.blank?
      raise ArgumentError, "account must be an Account instance" unless account.is_a?(::Account)
    end

    def self.build_provider(provider, api_key:)
      case provider
      when :openai    then Providers::OpenAI.new(api_key: api_key)
      when :anthropic then Providers::Anthropic.new(api_key: api_key)
      else raise ProviderNotFoundError, "Unsupported provider: #{provider.inspect}"
      end
    end
  end
end
