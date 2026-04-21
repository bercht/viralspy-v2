require "rails_helper"

RSpec.describe MediaGeneration::Factory do
  describe ".build" do
    it "retorna instância de Heygen para provider 'heygen'" do
      provider = described_class.build(provider: "heygen", api_key: "test_key")
      expect(provider).to be_a(MediaGeneration::Providers::Heygen)
    end

    it "retorna instância de Heygen para provider :heygen (symbol)" do
      provider = described_class.build(provider: :heygen, api_key: "test_key")
      expect(provider).to be_a(MediaGeneration::Providers::Heygen)
    end

    it "levanta Errors::Base para provider desconhecido" do
      expect {
        described_class.build(provider: "freepik", api_key: "test_key")
      }.to raise_error(MediaGeneration::Errors::Base, /Unknown media generation provider/)
    end
  end
end
