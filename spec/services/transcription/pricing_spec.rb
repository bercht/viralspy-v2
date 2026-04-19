# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::Pricing do
  describe ".cost_cents" do
    it "calculates correctly for 60 seconds with gpt-4o-mini-transcribe" do
      # 60s = 1 min @ $0.003/min * 5.50 BRL/USD * 100 cents = 1.65 cents ≈ 2
      result = described_class.cost_cents(
        provider: :openai,
        model: "gpt-4o-mini-transcribe",
        duration_seconds: 60
      )
      expect(result).to eq(2)
    end

    it "calculates correctly for 120 seconds" do
      # 120s = 2 min @ $0.003/min = $0.006 * 5.50 = 0.033 BRL = 3.3 cents ≈ 3
      result = described_class.cost_cents(
        provider: :openai,
        model: "gpt-4o-mini-transcribe",
        duration_seconds: 120
      )
      expect(result).to eq(3)
    end

    it "returns 0 when duration_seconds is nil" do
      result = described_class.cost_cents(
        provider: :openai,
        model: "gpt-4o-mini-transcribe",
        duration_seconds: nil
      )
      expect(result).to eq(0)
    end

    it "returns 0 when duration_seconds is 0" do
      result = described_class.cost_cents(
        provider: :openai,
        model: "gpt-4o-mini-transcribe",
        duration_seconds: 0
      )
      expect(result).to eq(0)
    end

    it "returns 0 for unknown model" do
      result = described_class.cost_cents(
        provider: :openai,
        model: "whisper-1",
        duration_seconds: 60
      )
      expect(result).to eq(0)
    end
  end

  describe ".known_model?" do
    it "returns true for known model" do
      expect(described_class.known_model?(provider: :openai, model: "gpt-4o-mini-transcribe")).to be true
    end

    it "returns false for unknown model" do
      expect(described_class.known_model?(provider: :openai, model: "whisper-1")).to be false
    end
  end
end
