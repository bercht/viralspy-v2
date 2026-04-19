# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::Providers::Base do
  let(:subclass) do
    Class.new(described_class) do
      def complete(model:, messages:, system: nil, json_mode: false, temperature: 0.7, max_tokens: DEFAULT_MAX_TOKENS)
        yield if block_given?
        "implemented"
      end

      def call_with_retry(&block)
        with_retry(&block)
      end
    end
  end

  describe "#initialize" do
    it "raises MissingApiKeyError when api_key is nil" do
      expect { described_class.new(api_key: nil) }.to raise_error(LLM::MissingApiKeyError)
    end

    it "raises MissingApiKeyError when api_key is empty string" do
      expect { described_class.new(api_key: "") }.to raise_error(LLM::MissingApiKeyError)
    end

    it "initializes successfully with valid api_key" do
      expect { described_class.new(api_key: "valid-key") }.not_to raise_error
    end
  end

  describe "#complete" do
    it "raises NotImplementedError on base class" do
      provider = described_class.new(api_key: "key")
      expect {
        provider.complete(model: "m", messages: [])
      }.to raise_error(NotImplementedError)
    end
  end

  describe "#with_retry" do
    let(:provider) { subclass.new(api_key: "key") }

    it "retries twice on RateLimitError then raises" do
      attempts = 0
      expect {
        provider.call_with_retry do
          attempts += 1
          raise LLM::RateLimitError, "too fast"
        end
      }.to raise_error(LLM::RateLimitError)
      expect(attempts).to eq(3)
    end

    it "retries twice on TimeoutError then raises" do
      attempts = 0
      expect {
        provider.call_with_retry do
          attempts += 1
          raise LLM::TimeoutError, "slow"
        end
      }.to raise_error(LLM::TimeoutError)
      expect(attempts).to eq(3)
    end

    it "does not retry on AuthenticationError" do
      attempts = 0
      expect {
        provider.call_with_retry do
          attempts += 1
          raise LLM::AuthenticationError, "bad key"
        end
      }.to raise_error(LLM::AuthenticationError)
      expect(attempts).to eq(1)
    end

    it "does not retry on InvalidRequestError" do
      attempts = 0
      expect {
        provider.call_with_retry do
          attempts += 1
          raise LLM::InvalidRequestError, "bad params"
        end
      }.to raise_error(LLM::InvalidRequestError)
      expect(attempts).to eq(1)
    end

    it "succeeds on second attempt after RateLimitError" do
      attempts = 0
      result = provider.call_with_retry do
        attempts += 1
        raise LLM::RateLimitError, "rate" if attempts < 2

        "success"
      end
      expect(result).to eq("success")
      expect(attempts).to eq(2)
    end
  end
end
