# frozen_string_literal: true

module LLM
  module Pricing
    RATES = {
      openai: {
        "gpt-4o" => { input: 2.50, output: 10.00 },
        "gpt-4o-mini" => { input: 0.15, output: 0.60 }
      },
      anthropic: {
        "claude-3-5-sonnet-20241022" => { input: 3.00, output: 15.00 },
        "claude-3-5-sonnet-latest" => { input: 3.00, output: 15.00 },
        "claude-3-5-haiku-20241022" => { input: 0.80, output: 4.00 },
        "claude-opus-4-7" => { input: 15.00, output: 75.00 },
        "claude-sonnet-4-5" => { input: 3.00, output: 15.00 }
      }
    }.freeze

    USD_TO_BRL = 5.50

    def self.cost_cents(provider:, model:, prompt_tokens:, completion_tokens:)
      rate = RATES.dig(provider, model)
      return 0 unless rate

      input_usd = (prompt_tokens / 1_000_000.0) * rate[:input]
      output_usd = (completion_tokens / 1_000_000.0) * rate[:output]
      total_brl = (input_usd + output_usd) * USD_TO_BRL
      (total_brl * 100).round
    end

    def self.known_model?(provider:, model:)
      RATES.dig(provider, model).present?
    end
  end
end
