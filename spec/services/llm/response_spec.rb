# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::Response do
  let(:response) do
    described_class.new(
      content: "Hello!",
      raw: { "id" => "test" },
      usage: { prompt_tokens: 10, completion_tokens: 5 },
      model: "gpt-4o-mini",
      provider: :openai,
      finish_reason: "stop"
    )
  end

  describe "#attributes" do
    it "exposes content, model, provider, finish_reason, raw" do
      expect(response.content).to eq("Hello!")
      expect(response.model).to eq("gpt-4o-mini")
      expect(response.provider).to eq(:openai)
      expect(response.finish_reason).to eq("stop")
      expect(response.raw).to eq({ "id" => "test" })
    end
  end

  describe "#prompt_tokens" do
    it "reads symbol keys" do
      r = described_class.new(content: "", raw: {}, usage: { prompt_tokens: 10, completion_tokens: 5 }, model: "m", provider: :openai)
      expect(r.prompt_tokens).to eq(10)
    end

    it "reads string keys" do
      r = described_class.new(content: "", raw: {}, usage: { "prompt_tokens" => 7, "completion_tokens" => 3 }, model: "m", provider: :openai)
      expect(r.prompt_tokens).to eq(7)
    end

    it "defaults to 0 when missing" do
      r = described_class.new(content: "", raw: {}, usage: {}, model: "m", provider: :openai)
      expect(r.prompt_tokens).to eq(0)
    end
  end

  describe "#completion_tokens" do
    it "reads symbol keys" do
      expect(response.completion_tokens).to eq(5)
    end

    it "reads string keys" do
      r = described_class.new(content: "", raw: {}, usage: { "completion_tokens" => 8 }, model: "m", provider: :openai)
      expect(r.completion_tokens).to eq(8)
    end
  end

  describe "#total_tokens" do
    it "sums prompt and completion tokens" do
      expect(response.total_tokens).to eq(15)
    end
  end

  describe "#parsed_json" do
    it "parses content as JSON" do
      r = described_class.new(content: '{"key":"value"}', raw: {}, usage: {}, model: "m", provider: :openai)
      expect(r.parsed_json).to eq({ "key" => "value" })
    end

    it "raises ResponseParseError on invalid JSON" do
      r = described_class.new(content: "not json", raw: {}, usage: {}, model: "m", provider: :openai)
      expect { r.parsed_json }.to raise_error(LLM::ResponseParseError, /Failed to parse/)
    end
  end

  describe "#success?" do
    it "always returns true" do
      expect(response.success?).to be true
    end
  end
end
