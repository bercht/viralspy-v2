# frozen_string_literal: true

module LLM
  module Pricing
    RATES = {
      openai: {
        "gpt-4o"      => { input: 2.50, output: 10.00 },
        "gpt-4o-mini" => { input: 0.15, output:  0.60 }
      },
      anthropic: {
        # Legacy (mantido para compatibilidade com analyses antigos)
        "claude-3-5-sonnet-20241022" => { input:  3.00, output: 15.00 },
        "claude-3-5-sonnet-latest"   => { input:  3.00, output: 15.00 },
        "claude-3-5-haiku-20241022"  => { input:  0.80, output:  4.00 },

        # Claude 4.x series (atual)
        # Nota: claude-opus-4-7 usa tokenizer novo que conta ~1.0–1.35x mais tokens
        # que o 4-6 para o mesmo input. O preço por token é igual; o custo efetivo
        # por request pode ser maior. LLM::Pricing recebe tokens já contados pela API.
        "claude-sonnet-4-5"         => { input:  3.00, output: 15.00 },
        "claude-sonnet-4-6"         => { input:  3.00, output: 15.00 },
        "claude-haiku-4-5-20251001" => { input:  1.00, output:  5.00 },
        "claude-opus-4-6"           => { input:  5.00, output: 25.00 },
        "claude-opus-4-7"           => { input:  5.00, output: 25.00 }
      }
    }.freeze

    USD_TO_BRL = 5.00

    def self.cost_cents(provider:, model:, prompt_tokens:, completion_tokens:)
      rate = RATES.dig(provider, model)

      if rate.nil?
        Rails.logger.warn(
          "[LLM::Pricing] Unknown model — cost logged as 0. " \
          "provider=#{provider} model=#{model}. " \
          "Add pricing to LLM::Pricing::RATES to fix."
        )
        return 0
      end

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
