# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::Pricing do
  describe ".cost_cents" do
    it "calculates correctly for gpt-4o-mini" do
      # 1000 prompt @ $0.15/1M + 500 completion @ $0.60/1M
      # = (0.0015 + 0.0003) USD = 0.00018 USD * 5.50 = 0.00099 BRL = 0.099 cents ≈ 0
      # Let's use bigger numbers: 100_000 prompt + 50_000 completion
      # = (0.015 + 0.03) USD = 0.045 USD * 5.50 = 0.2475 BRL = 24.75 cents ≈ 25
      result = described_class.cost_cents(
        provider: :openai,
        model: "gpt-4o-mini",
        prompt_tokens: 100_000,
        completion_tokens: 50_000
      )
      expect(result).to eq(25)
    end

    it "calculates correctly for gpt-4o" do
      # 1_000_000 prompt @ $2.50/1M + 1_000_000 completion @ $10.00/1M
      # = 12.50 USD * 5.50 = 68.75 BRL = 6875 cents
      result = described_class.cost_cents(
        provider: :openai,
        model: "gpt-4o",
        prompt_tokens: 1_000_000,
        completion_tokens: 1_000_000
      )
      expect(result).to eq(6875)
    end

    it "calculates correctly for claude-3-5-sonnet-20241022" do
      # 1_000_000 prompt @ $3.00/1M + 1_000_000 completion @ $15.00/1M
      # = 18.00 USD * 5.50 = 99.00 BRL = 9900 cents
      result = described_class.cost_cents(
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022",
        prompt_tokens: 1_000_000,
        completion_tokens: 1_000_000
      )
      expect(result).to eq(9900)
    end

    it "returns 0 for unknown model" do
      result = described_class.cost_cents(
        provider: :openai,
        model: "gpt-9000",
        prompt_tokens: 1000,
        completion_tokens: 500
      )
      expect(result).to eq(0)
    end

    it "returns 0 for unknown provider" do
      result = described_class.cost_cents(
        provider: :cohere,
        model: "command-r",
        prompt_tokens: 1000,
        completion_tokens: 500
      )
      expect(result).to eq(0)
    end
  end

  describe "Claude 4.x models" do
    it "prices claude-sonnet-4-6 at 3/15 USD per 1M tokens" do
      # 1M input @ $3 + 1M output @ $15 = $18 USD * 5.50 = $99 BRL = 9900 cents
      expect(described_class.cost_cents(
        provider: :anthropic, model: "claude-sonnet-4-6",
        prompt_tokens: 1_000_000, completion_tokens: 1_000_000
      )).to eq(9900)
    end

    it "prices claude-opus-4-6 at 5/25 USD per 1M tokens" do
      # 1M input @ $5 + 1M output @ $25 = $30 USD * 5.50 = $165 BRL = 16500 cents
      expect(described_class.cost_cents(
        provider: :anthropic, model: "claude-opus-4-6",
        prompt_tokens: 1_000_000, completion_tokens: 1_000_000
      )).to eq(16500)
    end

    it "prices claude-opus-4-7 at 5/25 USD per 1M tokens" do
      expect(described_class.cost_cents(
        provider: :anthropic, model: "claude-opus-4-7",
        prompt_tokens: 1_000_000, completion_tokens: 1_000_000
      )).to eq(16500)
    end

    it "prices claude-haiku-4-5-20251001 at 1/5 USD per 1M tokens" do
      # 1M input @ $1 + 1M output @ $5 = $6 USD * 5.50 = $33 BRL = 3300 cents
      expect(described_class.cost_cents(
        provider: :anthropic, model: "claude-haiku-4-5-20251001",
        prompt_tokens: 1_000_000, completion_tokens: 1_000_000
      )).to eq(3300)
    end
  end

  describe "unknown model warning" do
    it "logs a warning and returns 0 for unknown model" do
      expect(Rails.logger).to receive(:warn).with(/Unknown model.*claude-sonnet-9000/)
      expect(described_class.cost_cents(
        provider: :anthropic, model: "claude-sonnet-9000",
        prompt_tokens: 1000, completion_tokens: 500
      )).to eq(0)
    end

    it "does not log a warning for known models" do
      expect(Rails.logger).not_to receive(:warn)
      described_class.cost_cents(
        provider: :anthropic, model: "claude-sonnet-4-5",
        prompt_tokens: 1000, completion_tokens: 500
      )
    end
  end

  describe ".known_model?" do
    it "returns true for known models" do
      expect(described_class.known_model?(provider: :openai, model: "gpt-4o-mini")).to be true
      expect(described_class.known_model?(provider: :anthropic, model: "claude-3-5-sonnet-20241022")).to be true
    end

    it "returns false for unknown models" do
      expect(described_class.known_model?(provider: :openai, model: "gpt-9000")).to be false
      expect(described_class.known_model?(provider: :cohere, model: "command-r")).to be false
    end
  end
end
