module MediaGeneration
  class Factory
    PROVIDERS = {
      "heygen" => "MediaGeneration::Providers::Heygen"
    }.freeze

    def self.build(provider:, api_key:)
      provider_class = PROVIDERS.fetch(provider.to_s) do
        raise Errors::Base, "Unknown media generation provider: #{provider}"
      end
      provider_class.constantize.new(api_key: api_key)
    end
  end
end
