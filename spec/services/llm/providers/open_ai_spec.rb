# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::Providers::OpenAI do
  let(:provider) { described_class.new(api_key: "test-key") }
  let(:messages) { [ { role: "user", content: "Hello" } ] }
  let(:success_body) do
    {
      id: "chatcmpl-test",
      object: "chat.completion",
      choices: [
        {
          index: 0,
          message: { role: "assistant", content: "Hi there!" },
          finish_reason: "stop"
        }
      ],
      usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
      model: "gpt-4o-mini"
    }.to_json
  end

  describe "#initialize" do
    it "raises MissingApiKeyError without api_key" do
      expect { described_class.new(api_key: nil) }.to raise_error(LLM::MissingApiKeyError)
    end

    it "raises ArgumentError when called without api_key keyword" do
      expect { described_class.new }.to raise_error(ArgumentError, /api_key/)
    end
  end

  describe "#complete" do
    context "successful response" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })
      end

      it "returns LLM::Response" do
        response = provider.complete(model: "gpt-4o-mini", messages: messages)
        expect(response).to be_a(LLM::Response)
        expect(response.content).to eq("Hi there!")
        expect(response.prompt_tokens).to eq(10)
        expect(response.completion_tokens).to eq(5)
        expect(response.provider).to eq(:openai)
        expect(response.model).to eq("gpt-4o-mini")
        expect(response.finish_reason).to eq("stop")
      end

      it "prepends system prompt as first message" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            body["messages"].first["role"] == "system" &&
              body["messages"].first["content"] == "You are helpful"
          }
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

        provider.complete(model: "gpt-4o-mini", messages: messages, system: "You are helpful")
      end

      it "includes response_format for json_mode" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            body["response_format"] == { "type" => "json_object" }
          }
          .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

        provider.complete(model: "gpt-4o-mini", messages: messages, json_mode: true)
      end
    end

    context "error responses" do
      it "raises RateLimitError on 429" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(status: 429, body: { error: { message: "Rate limit exceeded", type: "rate_limit_error" } }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect {
          provider.complete(model: "gpt-4o-mini", messages: messages)
        }.to raise_error(LLM::RateLimitError)
      end

      it "raises AuthenticationError on 401" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(status: 401, body: { error: { message: "Invalid API key", type: "invalid_request_error" } }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect {
          provider.complete(model: "gpt-4o-mini", messages: messages)
        }.to raise_error(LLM::AuthenticationError)
      end

      it "raises InvalidRequestError on 400" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(status: 400, body: { error: { message: "Bad request", type: "invalid_request_error" } }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect {
          provider.complete(model: "gpt-4o-mini", messages: messages)
        }.to raise_error(LLM::InvalidRequestError)
      end

      it "retries on RateLimitError and succeeds on second attempt" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(
            { status: 429, body: { error: { message: "Rate limit", type: "rate_limit_error" } }.to_json,
              headers: { "Content-Type" => "application/json" } },
            { status: 200, body: success_body, headers: { "Content-Type" => "application/json" } }
          )

        response = provider.complete(model: "gpt-4o-mini", messages: messages)
        expect(response.content).to eq("Hi there!")
      end

      it "raises ResponseParseError when response has no choices" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(status: 200, body: { id: "x", choices: [] }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect {
          provider.complete(model: "gpt-4o-mini", messages: messages)
        }.to raise_error(LLM::ResponseParseError)
      end
    end
  end
end
