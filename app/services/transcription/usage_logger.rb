# frozen_string_literal: true

module Transcription
  class UsageLogger
    def self.log(result:, account:, provider:, model:, post: nil, analysis: nil)
      return nil unless result.success?

      new(result: result, account: account, provider: provider, model: model, post: post, analysis: analysis).log
    end

    def initialize(result:, account:, provider:, model:, post: nil, analysis: nil)
      @result = result
      @account = account
      @provider = provider
      @model = model
      @post = post
      @analysis = analysis
    end

    def log
      cost = Transcription::Pricing.cost_cents(
        provider: provider,
        model: model,
        duration_seconds: result.duration_seconds
      )

      ActsAsTenant.with_tenant(account) do
        ::TranscriptionUsageLog.create!(
          account: account,
          provider: provider.to_s,
          model: model,
          audio_duration_seconds: result.duration_seconds,
          cost_cents: cost,
          post: post,
          analysis: analysis
        )
      end
    end

    private

    attr_reader :result, :account, :provider, :model, :post, :analysis
  end
end
