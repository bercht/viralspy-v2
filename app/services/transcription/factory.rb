# frozen_string_literal: true

module Transcription
  module Factory
    module_function

    def build(provider:, api_key:)
      case provider.to_s.downcase
      when "openai"
        Providers::OpenAI.new(api_key: api_key)
      when "assemblyai"
        Providers::AssemblyAI.new(api_key: api_key)
      else
        raise ProviderNotFoundError, "Unsupported transcription provider: #{provider}"
      end
    end
  end
end
