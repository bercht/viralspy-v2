# frozen_string_literal: true

module Transcription
  module Factory
    module_function

    def build(api_key:, provider_name: ENV.fetch("TRANSCRIPTION_PROVIDER", "openai"))
      case provider_name.to_s.downcase
      when "openai"
        Providers::OpenAI.new(api_key: api_key)
      when "assemblyai"
        Providers::AssemblyAI.new(api_key: api_key)
      else
        raise ProviderNotFoundError, "Unsupported transcription provider: #{provider_name}"
      end
    end
  end
end
