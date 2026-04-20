# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LLM integration", :vcr do
  let(:account) { create(:account) }

  around do |example|
    original_openai = ENV["OPENAI_API_KEY"]
    original_anthropic = ENV["ANTHROPIC_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key-vcr" if original_openai.blank?
    ENV["ANTHROPIC_API_KEY"] = "test-key-vcr" if original_anthropic.blank?
    example.run
  ensure
    ENV["OPENAI_API_KEY"] = original_openai
    ENV["ANTHROPIC_API_KEY"] = original_anthropic
  end

  describe "OpenAI provider" do
    it "completes a minimal prompt and logs usage", vcr: { cassette_name: "llm/openai_complete" } do
      ActsAsTenant.with_tenant(account) do
        response = LLM::Gateway.complete(
          provider: :openai,
          model: "gpt-4o-mini",
          messages: [ { role: "user", content: "Reply with the word OK only." } ],
          max_tokens: 10,
          use_case: "integration_test",
          account: account,
          api_key: ENV.fetch("OPENAI_API_KEY", "test-key-vcr")
        )

        expect(response).to be_a(LLM::Response)
        expect(response.content).to be_present
        expect(response.provider).to eq(:openai)
        expect(response.prompt_tokens).to be > 0
        expect(response.completion_tokens).to be > 0

        log = ::LLMUsageLog.last
        expect(log).to be_present
        expect(log.use_case).to eq("integration_test")
        expect(log.provider).to eq("openai")
      end
    end
  end

  describe "Anthropic provider" do
    it "completes a minimal prompt and logs usage", vcr: { cassette_name: "llm/anthropic_complete" } do
      ActsAsTenant.with_tenant(account) do
        response = LLM::Gateway.complete(
          provider: :anthropic,
          model: "claude-3-5-haiku-20241022",
          messages: [ { role: "user", content: "Reply with the word OK only." } ],
          max_tokens: 10,
          use_case: "integration_test",
          account: account,
          api_key: ENV.fetch("ANTHROPIC_API_KEY", "test-key-vcr")
        )

        expect(response).to be_a(LLM::Response)
        expect(response.content).to be_present
        expect(response.provider).to eq(:anthropic)
        expect(response.prompt_tokens).to be > 0
        expect(response.completion_tokens).to be > 0

        log = ::LLMUsageLog.last
        expect(log).to be_present
        expect(log.use_case).to eq("integration_test")
        expect(log.provider).to eq("anthropic")
      end
    end
  end
end
