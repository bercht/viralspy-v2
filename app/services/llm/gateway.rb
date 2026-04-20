# frozen_string_literal: true

module LLM
  class Gateway
    SUPPORTED_PROVIDERS = %i[openai anthropic].freeze

    def self.complete(provider:, model:, messages:, use_case:, account:,
                      api_key: nil,
                      system: nil, json_mode: false, temperature: 0.7,
                      max_tokens: Providers::Base::DEFAULT_MAX_TOKENS,
                      analysis: nil)
      validate_args!(provider: provider, use_case: use_case, account: account)

      resolved_key = api_key || legacy_env_api_key_for(provider)
      raise LLM::MissingApiKeyError, "API key missing for provider #{provider}" if resolved_key.blank?

      provider_instance = build_provider(provider, api_key: resolved_key)
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

    # TRANSITORY — removed in Tarefa 2.4 of Fase 1.5b.
    # Only used while callers are being migrated to pass api_key explicitly.
    def self.legacy_env_api_key_for(provider)
      case provider
      when :openai    then ENV["OPENAI_API_KEY"]
      when :anthropic then ENV["ANTHROPIC_API_KEY"]
      end
    end

    private_class_method :legacy_env_api_key_for
  end
end
