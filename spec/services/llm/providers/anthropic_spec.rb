# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::Providers::Anthropic do
  let(:provider) { described_class.new(api_key: "test-key") }
  let(:messages) { [ { role: "user", content: "Hello" } ] }
  let(:success_body) do
    {
      id: "msg_test123",
      type: "message",
      role: "assistant",
      content: [ { type: "text", text: "Hi there!" } ],
      model: "claude-3-5-sonnet-20241022",
      stop_reason: "end_turn",
      stop_sequence: nil,
      stop_details: nil,
      container: nil,
      usage: {
        input_tokens: 10,
        output_tokens: 5,
        cache_creation_input_tokens: nil,
        cache_read_input_tokens: nil
      }
    }.to_json
  end

  describe "#initialize" do
    it "raises MissingApiKeyError without api_key" do
      expect { described_class.new(api_key: nil) }.to raise_error(LLM::MissingApiKeyError)
    end
  end

  describe "#complete" do
    context "successful response" do
      before do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })
      end

      it "returns LLM::Response" do
        response = provider.complete(model: "claude-3-5-sonnet-20241022", messages: messages)
        expect(response).to be_a(LLM::Response)
        expect(response.content).to eq("Hi there!")
        expect(response.prompt_tokens).to eq(10)
        expect(response.completion_tokens).to eq(5)
        expect(response.provider).to eq(:anthropic)
        expect(response.model).to eq("claude-3-5-sonnet-20241022")
      end

      it "filters out system role messages from messages array" do
        messages_with_system = [ { role: "system", content: "Be helpful" }, { role: "user", content: "Hi" } ]
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .with { |req|
            body = JSON.parse(req.body)
            body["messages"].none? { |m| m["role"] == "system" }
          }
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

        provider.complete(model: "claude-3-5-sonnet-20241022", messages: messages_with_system)
      end

      it "sends system as separate parameter" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .with { |req|
            body = JSON.parse(req.body)
            body["system"] == "You are helpful"
          }
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

        provider.complete(model: "claude-3-5-sonnet-20241022", messages: messages, system: "You are helpful")
      end

      it "appends JSON instruction when json_mode is true" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .with { |req|
            body = JSON.parse(req.body)
            body["system"]&.include?("valid JSON only")
          }
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

        provider.complete(model: "claude-3-5-sonnet-20241022", messages: messages, json_mode: true)
      end
    end

    context "temperature handling" do
      it "omits temperature from HTTP payload when nil" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .with { |req|
            body = JSON.parse(req.body)
            !body.key?("temperature")
          }
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

        provider.complete(model: "claude-opus-4-7", messages: messages, temperature: nil)
      end

      it "includes temperature in HTTP payload when explicitly provided" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .with { |req|
            body = JSON.parse(req.body)
            body["temperature"] == 0.5
          }
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

        provider.complete(model: "claude-3-5-sonnet-latest", messages: messages, temperature: 0.5)
      end

      it "includes temperature 0.7 in HTTP payload when using default" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .with { |req|
            body = JSON.parse(req.body)
            body["temperature"] == 0.7
          }
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

        provider.complete(model: "claude-3-5-sonnet-latest", messages: messages)
      end
    end

    context "error responses" do
      it "raises RateLimitError on 429" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 429, body: { type: "error", error: { type: "rate_limit_error", message: "Rate limit exceeded" } }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect {
          provider.complete(model: "claude-3-5-sonnet-20241022", messages: messages)
        }.to raise_error(LLM::RateLimitError)
      end

      it "raises AuthenticationError on 401" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 401, body: { type: "error", error: { type: "authentication_error", message: "Invalid API key" } }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect {
          provider.complete(model: "claude-3-5-sonnet-20241022", messages: messages)
        }.to raise_error(LLM::AuthenticationError)
      end

      it "raises InvalidRequestError on 400" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 400, body: { type: "error", error: { type: "invalid_request_error", message: "Bad request" } }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect {
          provider.complete(model: "claude-3-5-sonnet-20241022", messages: messages)
        }.to raise_error(LLM::InvalidRequestError)
      end

      it "retries on RateLimitError and succeeds on second attempt" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            { status: 429, body: { type: "error", error: { type: "rate_limit_error", message: "Rate limit" } }.to_json,
              headers: { "Content-Type" => "application/json" } },
            { status: 200, body: success_body, headers: { "Content-Type" => "application/json" } }
          )

        response = provider.complete(model: "claude-3-5-sonnet-20241022", messages: messages)
        expect(response.content).to eq("Hi there!")
      end
    end
  end
end
