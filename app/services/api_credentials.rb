# frozen_string_literal: true

module ApiCredentials
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class QuotaExceededError < Error; end
  class UnknownError < Error; end

  class NotConfiguredError < Error
    attr_reader :provider, :use_case

    def initialize(provider:, use_case: nil)
      @provider = provider
      @use_case = use_case
      super(build_message)
    end

    private

    def build_message
      base = "No active API credential configured for provider '#{provider}'"
      base += " (use case: #{use_case})" if use_case
      base + ". Configure it at Settings → API Keys."
    end
  end
end
