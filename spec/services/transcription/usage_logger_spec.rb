# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::UsageLogger do
  let(:account) { create(:account) }
  let(:success_result) { Transcription::Result.success(transcript: "Hello", duration_seconds: 60) }
  let(:failure_result) { Transcription::Result.failure(error: "Too big", error_code: :file_too_large) }

  describe ".log" do
    context "with success result" do
      it "creates TranscriptionUsageLog" do
        ActsAsTenant.with_tenant(account) do
          expect {
            described_class.log(
              result: success_result,
              account: account,
              provider: :openai,
              model: "gpt-4o-mini-transcribe"
            )
          }.to change(TranscriptionUsageLog, :count).by(1)

          log = TranscriptionUsageLog.last
          expect(log.account).to eq(account)
          expect(log.provider).to eq("openai")
          expect(log.model).to eq("gpt-4o-mini-transcribe")
          expect(log.audio_duration_seconds).to eq(60)
          expect(log.cost_cents).to be >= 0
        end
      end

      it "calculates cost_cents via Transcription::Pricing" do
        ActsAsTenant.with_tenant(account) do
          described_class.log(result: success_result, account: account, provider: :openai, model: "gpt-4o-mini-transcribe")
          log = TranscriptionUsageLog.last
          expected = Transcription::Pricing.cost_cents(provider: :openai, model: "gpt-4o-mini-transcribe", duration_seconds: 60)
          expect(log.cost_cents).to eq(expected)
        end
      end

      it "scopes to correct tenant" do
        other_account = create(:account)
        ActsAsTenant.with_tenant(account) do
          described_class.log(result: success_result, account: account, provider: :openai, model: "gpt-4o-mini-transcribe")
        end
        ActsAsTenant.with_tenant(other_account) do
          expect(TranscriptionUsageLog.count).to eq(0)
        end
      end
    end

    context "with failure result" do
      it "does NOT create TranscriptionUsageLog" do
        ActsAsTenant.with_tenant(account) do
          expect {
            described_class.log(result: failure_result, account: account, provider: :openai, model: "gpt-4o-mini-transcribe")
          }.not_to change(TranscriptionUsageLog, :count)
        end
      end

      it "returns nil" do
        result = ActsAsTenant.with_tenant(account) do
          described_class.log(result: failure_result, account: account, provider: :openai, model: "gpt-4o-mini-transcribe")
        end
        expect(result).to be_nil
      end
    end
  end
end
