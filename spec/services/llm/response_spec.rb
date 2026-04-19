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
    def build_response(content)
      described_class.new(
        content: content,
        raw: {},
        usage: { prompt_tokens: 10, completion_tokens: 5 },
        model: "claude-sonnet-4-5",
        provider: :anthropic,
        finish_reason: "end_turn"
      )
    end

    context "with pure JSON (no fences)" do
      it "parses correctly" do
        expect(build_response('{"hooks": ["abc"]}').parsed_json).to eq({ "hooks" => [ "abc" ] })
      end

      it "parses nested JSON" do
        expect(build_response('{"a": {"b": [1, 2]}}').parsed_json).to eq({ "a" => { "b" => [ 1, 2 ] } })
      end
    end

    context "with markdown fence (Sonnet 4.x behavior)" do
      it "strips ```json fence" do
        r = build_response("```json\n{\"hooks\": [\"abc\"]}\n```")
        expect(r.parsed_json).to eq({ "hooks" => [ "abc" ] })
      end

      it "strips ``` fence without 'json' tag" do
        r = build_response("```\n{\"hooks\": [\"abc\"]}\n```")
        expect(r.parsed_json).to eq({ "hooks" => [ "abc" ] })
      end

      it "strips fences with trailing/leading whitespace" do
        r = build_response("  ```json  \n{\"hooks\": [\"abc\"]}\n  ```  ")
        expect(r.parsed_json).to eq({ "hooks" => [ "abc" ] })
      end

      it "is case-insensitive on the json tag" do
        r = build_response("```JSON\n{\"ok\": true}\n```")
        expect(r.parsed_json).to eq({ "ok" => true })
      end

      it "works with fence but no newline after ```json" do
        r = build_response('```json{"ok": true}```')
        expect(r.parsed_json).to eq({ "ok" => true })
      end
    end

    context "with malformed JSON" do
      it "raises ResponseParseError" do
        r = described_class.new(content: "not json", raw: {}, usage: {}, model: "m", provider: :openai)
        expect { r.parsed_json }.to raise_error(LLM::ResponseParseError, /Failed to parse/)
      end

      it "raises ResponseParseError when fence wraps non-JSON" do
        r = build_response("```json\nthis is not valid json\n```")
        expect { r.parsed_json }.to raise_error(LLM::ResponseParseError)
      end
    end

    context "memoization" do
      it "parses only once" do
        r = build_response('{"n": 1}')
        expect(r.parsed_json.object_id).to eq(r.parsed_json.object_id)
      end
    end
  end

  describe "#success?" do
    it "always returns true" do
      expect(response.success?).to be true
    end
  end
end
