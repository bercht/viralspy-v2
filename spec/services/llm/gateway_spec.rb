# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::Gateway do
  let(:account) { create(:account) }
  let(:mock_response) do
    LLM::Response.new(
      content: "Hi!",
      raw: {},
      usage: { prompt_tokens: 100_000, completion_tokens: 50_000 },
      model: "gpt-4o-mini",
      provider: :openai
    )
  end
  let(:mock_provider) { instance_double(LLM::Providers::OpenAI) }

  describe ".complete" do
    before do
      allow(described_class).to receive(:build_provider).with(:openai, api_key: instance_of(String)).and_return(mock_provider)
      allow(mock_provider).to receive(:complete).and_return(mock_response)
    end

    it "creates LLMUsageLog on success" do
      ActsAsTenant.with_tenant(account) do
        expect {
          described_class.complete(
            provider: :openai,
            model: "gpt-4o-mini",
            messages: [ { role: "user", content: "Hi" } ],
            use_case: "test",
            account: account,
            api_key: "test-key"
          )
        }.to change(::LLMUsageLog, :count).by(1)
      end
    end

    it "returns the LLM::Response" do
      ActsAsTenant.with_tenant(account) do
        result = described_class.complete(
          provider: :openai, model: "gpt-4o-mini",
          messages: [ { role: "user", content: "Hi" } ],
          use_case: "test", account: account,
          api_key: "test-key"
        )
        expect(result).to be_a(LLM::Response)
        expect(result.content).to eq("Hi!")
      end
    end

    it "raises ProviderNotFoundError for unsupported provider" do
      expect {
        described_class.complete(
          provider: :cohere, model: "command-r",
          messages: [], use_case: "test", account: account,
          api_key: "test-key"
        )
      }.to raise_error(LLM::ProviderNotFoundError)
    end

    it "raises ArgumentError for blank use_case" do
      expect {
        described_class.complete(
          provider: :openai, model: "gpt-4o-mini",
          messages: [], use_case: "", account: account,
          api_key: "test-key"
        )
      }.to raise_error(ArgumentError, /use_case/)
    end

    it "raises ArgumentError when account is not an Account" do
      expect {
        described_class.complete(
          provider: :openai, model: "gpt-4o-mini",
          messages: [], use_case: "test", account: "not-an-account",
          api_key: "test-key"
        )
      }.to raise_error(ArgumentError, /account/)
    end

    it "does NOT create LLMUsageLog when provider raises an error" do
      allow(mock_provider).to receive(:complete).and_raise(LLM::RateLimitError, "too fast")

      ActsAsTenant.with_tenant(account) do
        expect {
          described_class.complete(
            provider: :openai, model: "gpt-4o-mini",
            messages: [], use_case: "test", account: account,
            api_key: "test-key"
          ) rescue nil
        }.not_to change(::LLMUsageLog, :count)
      end
    end

    it "propagates errors from the provider" do
      allow(mock_provider).to receive(:complete).and_raise(LLM::RateLimitError, "slow down")

      ActsAsTenant.with_tenant(account) do
        expect {
          described_class.complete(
            provider: :openai, model: "gpt-4o-mini",
            messages: [], use_case: "test", account: account,
            api_key: "test-key"
          )
        }.to raise_error(LLM::RateLimitError)
      end
    end

    it "routes :anthropic to Anthropic provider" do
      mock_anthropic = instance_double(LLM::Providers::Anthropic)
      allow(described_class).to receive(:build_provider).with(:anthropic, api_key: instance_of(String)).and_return(mock_anthropic)
      allow(mock_anthropic).to receive(:complete).and_return(mock_response)

      ActsAsTenant.with_tenant(account) do
        result = described_class.complete(
          provider: :anthropic, model: "claude-3-5-sonnet-20241022",
          messages: [ { role: "user", content: "Hi" } ],
          use_case: "test", account: account,
          api_key: "test-key"
        )
        expect(result).to be_a(LLM::Response)
      end
    end

    describe "api_key resolution" do
      it "passes explicit api_key to build_provider" do
        expect(described_class).to receive(:build_provider).with(:openai, api_key: "explicit-key").and_return(mock_provider)

        ActsAsTenant.with_tenant(account) do
          described_class.complete(
            provider: :openai, model: "gpt-4o-mini",
            messages: [ { role: "user", content: "hi" } ],
            use_case: "test", account: account,
            api_key: "explicit-key"
          )
        end
      end

      it "falls back to ENV when api_key not provided (legacy migration path)" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("env-key")
        expect(described_class).to receive(:build_provider).with(:openai, api_key: "env-key").and_return(mock_provider)

        ActsAsTenant.with_tenant(account) do
          described_class.complete(
            provider: :openai, model: "gpt-4o-mini",
            messages: [ { role: "user", content: "hi" } ],
            use_case: "test", account: account
          )
        end
      end

      it "raises MissingApiKeyError when no api_key and no ENV" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

        expect {
          described_class.complete(
            provider: :openai, model: "gpt-4o-mini",
            messages: [ { role: "user", content: "hi" } ],
            use_case: "test", account: account
          )
        }.to raise_error(LLM::MissingApiKeyError)
      end
    end
  end
end
