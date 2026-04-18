# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::UsageLogger do
  let(:account) { create(:account) }
  let(:response) do
    LLM::Response.new(
      content: "Hi",
      raw: {},
      usage: { prompt_tokens: 100, completion_tokens: 50 },
      model: "gpt-4o-mini",
      provider: :openai
    )
  end

  describe ".log" do
    it "creates an ::LLMUsageLog with all fields" do
      ActsAsTenant.with_tenant(account) do
        expect {
          described_class.log(response: response, account: account, use_case: "test_case")
        }.to change(::LLMUsageLog, :count).by(1)

        log = ::LLMUsageLog.last
        expect(log.account).to eq(account)
        expect(log.provider).to eq("openai")
        expect(log.model).to eq("gpt-4o-mini")
        expect(log.use_case).to eq("test_case")
        expect(log.prompt_tokens).to eq(100)
        expect(log.completion_tokens).to eq(50)
        expect(log.cost_cents).to be >= 0
      end
    end

    it "calculates cost_cents via Pricing" do
      ActsAsTenant.with_tenant(account) do
        described_class.log(response: response, account: account, use_case: "test")
        log = ::LLMUsageLog.last
        expected = LLM::Pricing.cost_cents(provider: :openai, model: "gpt-4o-mini", prompt_tokens: 100, completion_tokens: 50)
        expect(log.cost_cents).to eq(expected)
      end
    end

    it "works with analysis: nil" do
      ActsAsTenant.with_tenant(account) do
        expect {
          described_class.log(response: response, account: account, use_case: "test", analysis: nil)
        }.to change(::LLMUsageLog, :count).by(1)
      end
    end

    it "scopes log to correct tenant" do
      other_account = create(:account)
      ActsAsTenant.with_tenant(account) do
        described_class.log(response: response, account: account, use_case: "test")
      end
      ActsAsTenant.with_tenant(other_account) do
        expect(::LLMUsageLog.count).to eq(0)
      end
    end
  end
end
