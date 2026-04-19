# frozen_string_literal: true

module LLM
  class Gateway
    SUPPORTED_PROVIDERS = %i[openai anthropic].freeze

    def self.complete(provider:, model:, messages:, use_case:, account:,
                      system: nil, json_mode: false, temperature: 0.7,
                      max_tokens: Providers::Base::DEFAULT_MAX_TOKENS,
                      analysis: nil)
      validate_args!(provider: provider, use_case: use_case, account: account)

      provider_instance = build_provider(provider)
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

    def self.build_provider(provider)
      case provider
      when :openai then Providers::OpenAI.new
      when :anthropic then Providers::Anthropic.new
      else raise ProviderNotFoundError, "Unsupported provider: #{provider.inspect}"
      end
    end
  end
end
