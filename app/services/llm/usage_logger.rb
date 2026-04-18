# frozen_string_literal: true

module LLM
  class UsageLogger
    def self.log(response:, account:, use_case:, analysis: nil)
      new(response: response, account: account, use_case: use_case, analysis: analysis).log
    end

    def initialize(response:, account:, use_case:, analysis: nil)
      @response = response
      @account = account
      @use_case = use_case
      @analysis = analysis
    end

    def log
      cost = LLM::Pricing.cost_cents(
        provider: response.provider,
        model: response.model,
        prompt_tokens: response.prompt_tokens,
        completion_tokens: response.completion_tokens
      )

      ActsAsTenant.with_tenant(account) do
        ::LLMUsageLog.create!(
          account: account,
          provider: response.provider.to_s,
          model: response.model,
          use_case: use_case,
          prompt_tokens: response.prompt_tokens,
          completion_tokens: response.completion_tokens,
          cost_cents: cost,
          analysis: analysis
        )
      end
    end

    private

    attr_reader :response, :account, :use_case, :analysis
  end
end
