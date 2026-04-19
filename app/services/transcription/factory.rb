# frozen_string_literal: true

module Transcription
  module Factory
    module_function

    def build(provider_name = ENV.fetch("TRANSCRIPTION_PROVIDER", "openai"))
      case provider_name.to_s.downcase
      when "openai"
        Providers::OpenAI.new
      when "assemblyai"
        Providers::AssemblyAI.new
      else
        raise ProviderNotFoundError, "Unsupported transcription provider: #{provider_name}"
      end
    end
  end
end
