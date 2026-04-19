# frozen_string_literal: true

module LLM
  class Response
    attr_reader :content, :raw, :usage, :model, :provider, :finish_reason

    def initialize(content:, raw:, usage:, model:, provider:, finish_reason: nil)
      @content = content
      @raw = raw
      @usage = usage
      @model = model
      @provider = provider
      @finish_reason = finish_reason
    end

    def prompt_tokens
      usage[:prompt_tokens] || usage["prompt_tokens"] || 0
    end

    def completion_tokens
      usage[:completion_tokens] || usage["completion_tokens"] || 0
    end

    def total_tokens
      prompt_tokens + completion_tokens
    end

    def parsed_json
      @parsed_json ||= JSON.parse(sanitized_json_content)
    rescue JSON::ParserError => e
      raise LLM::ResponseParseError, "Failed to parse response as JSON: #{e.message}"
    end

    def success?
      true
    end

    private

    def sanitized_json_content
      stripped = content.to_s.strip
      stripped = stripped.sub(/\A```(?:json)?\s*\n?/i, "")
      stripped = stripped.sub(/\n?\s*```\s*\z/, "")
      stripped
    end
  end
end
