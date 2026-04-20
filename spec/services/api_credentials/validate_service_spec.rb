# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiCredentials::ValidateService do
  let(:account) { create(:account) }

  describe ".call" do
    context "openai provider" do
      let(:credential) do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "openai", encrypted_api_key: "sk-test-xyz")
        end
      end

      it "returns verified on 200 response" do
        stub_request(:get, "https://api.openai.com/v1/models")
          .to_return(status: 200, body: { data: [] }.to_json, headers: { "Content-Type" => "application/json" })

        result = described_class.call(credential)

        expect(result).to be_success
        expect(result.status).to eq(:verified)
        expect(credential.reload.last_validation_status).to eq("verified")
        expect(credential.reload.last_validated_at).to be_present
      end

      it "returns failed on 401 response" do
        stub_request(:get, "https://api.openai.com/v1/models")
          .to_return(
            status: 401,
            body: { error: { message: "Incorrect API key provided" } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result).to be_failure
        expect(result.status).to eq(:failed)
        expect(credential.reload.last_validation_status).to eq("failed")
      end

      it "returns quota_exceeded on 429 response" do
        stub_request(:get, "https://api.openai.com/v1/models")
          .to_return(
            status: 429,
            body: { error: { message: "Rate limit reached" } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result.status).to eq(:quota_exceeded)
        expect(credential.reload.last_validation_status).to eq("quota_exceeded")
      end

      it "returns unknown on 500 response" do
        stub_request(:get, "https://api.openai.com/v1/models")
          .to_return(status: 500, body: "Internal Server Error")

        result = described_class.call(credential)

        expect(result.status).to eq(:unknown)
        expect(credential.reload.last_validation_status).to eq("unknown")
      end

      it "returns unknown on timeout" do
        stub_request(:get, "https://api.openai.com/v1/models").to_timeout

        result = described_class.call(credential)

        expect(result.status).to eq(:unknown)
      end
    end

    context "anthropic provider" do
      let(:credential) do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test-xyz")
        end
      end

      it "returns verified on 200 response" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 200,
            body: {
              id: "msg_x",
              type: "message",
              role: "assistant",
              content: [ { type: "text", text: "ok" } ],
              model: "claude-3-5-haiku-latest",
              stop_reason: "end_turn",
              usage: { input_tokens: 1, output_tokens: 1 }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result).to be_success
        expect(credential.reload.last_validation_status).to eq("verified")
      end

      it "returns failed on 401" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 401,
            body: { type: "error", error: { type: "authentication_error", message: "invalid x-api-key" } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result.status).to eq(:failed)
        expect(credential.reload.last_validation_status).to eq("failed")
      end

      it "returns quota_exceeded on 429" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 429,
            body: { type: "error", error: { type: "rate_limit_error", message: "rate limit" } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result.status).to eq(:quota_exceeded)
        expect(credential.reload.last_validation_status).to eq("quota_exceeded")
      end

      it "returns unknown on 500" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 500,
            body: { type: "error", error: { type: "api_error", message: "internal" } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result.status).to eq(:unknown)
        expect(credential.reload.last_validation_status).to eq("unknown")
      end
    end

    context "assemblyai provider" do
      let(:credential) do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, :assemblyai, account: account, encrypted_api_key: "aai-test-xyz")
        end
      end

      # client.transcripts.list(limit: 1) bate em GET /v2/transcript?limit=1
      # Usando regex para flexibilidade com query strings adicionais

      it "returns verified on 200" do
        stub_request(:get, /api\.assemblyai\.com\/v2\/transcript/)
          .to_return(
            status: 200,
            body: { transcripts: [], page_details: { limit: 1 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result).to be_success
        expect(credential.reload.last_validation_status).to eq("verified")
      end

      it "returns failed on 401" do
        stub_request(:get, /api\.assemblyai\.com\/v2\/transcript/)
          .to_return(
            status: 401,
            body: { error: "Unauthorized - invalid api key" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result.status).to eq(:failed)
        expect(credential.reload.last_validation_status).to eq("failed")
      end

      it "returns quota_exceeded on 429" do
        stub_request(:get, /api\.assemblyai\.com\/v2\/transcript/)
          .to_return(
            status: 429,
            body: { error: "Rate limit exceeded" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = described_class.call(credential)

        expect(result.status).to eq(:quota_exceeded)
        expect(credential.reload.last_validation_status).to eq("quota_exceeded")
      end

      it "returns unknown on 500" do
        stub_request(:get, /api\.assemblyai\.com\/v2\/transcript/)
          .to_return(status: 500, body: "server error")

        result = described_class.call(credential)

        expect(result.status).to eq(:unknown)
        expect(credential.reload.last_validation_status).to eq("unknown")
      end
    end

    context "unsupported provider" do
      it "returns unknown when provider is somehow invalid" do
        ActsAsTenant.with_tenant(account) do
          credential = build(:api_credential, account: account, provider: "openai", encrypted_api_key: "x")
          credential.save!(validate: false)
          ApiCredential.where(id: credential.id).update_all(provider: "gemini")
          credential.reload

          result = described_class.call(credential)

          expect(result.status).to eq(:unknown)
          expect(credential.reload.last_validation_status).to eq("unknown")
        end
      end
    end

    context "persistence" do
      let(:credential) do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "openai", encrypted_api_key: "sk-test")
        end
      end

      it "updates last_validated_at on success" do
        stub_request(:get, "https://api.openai.com/v1/models")
          .to_return(status: 200, body: { data: [] }.to_json, headers: { "Content-Type" => "application/json" })

        travel_to Time.zone.parse("2026-04-20 15:00:00") do
          described_class.call(credential)
          expect(credential.reload.last_validated_at).to be_within(1.second).of(Time.zone.parse("2026-04-20 15:00:00"))
        end
      end

      it "updates last_validated_at on failure too" do
        stub_request(:get, "https://api.openai.com/v1/models")
          .to_return(status: 401, body: { error: { message: "Incorrect API key" } }.to_json,
                     headers: { "Content-Type" => "application/json" })

        described_class.call(credential)
        expect(credential.reload.last_validated_at).to be_present
      end
    end
  end
end
