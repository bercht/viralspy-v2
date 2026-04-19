# frozen_string_literal: true

module Transcription
  module Pricing
    RATES = {
      openai: {
        "gpt-4o-mini-transcribe" => 0.003
      }
    }.freeze

    USD_TO_BRL = 5.50

    def self.cost_cents(provider:, model:, duration_seconds:)
      return 0 if duration_seconds.nil? || duration_seconds <= 0

      rate_per_minute_usd = RATES.dig(provider, model)
      return 0 unless rate_per_minute_usd

      minutes = duration_seconds / 60.0
      total_brl = minutes * rate_per_minute_usd * USD_TO_BRL
      (total_brl * 100).round
    end

    def self.known_model?(provider:, model:)
      RATES.dig(provider, model).present?
    end
  end
end
