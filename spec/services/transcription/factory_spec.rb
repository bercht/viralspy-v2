# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::Factory do
  describe ".build" do
    it "returns OpenAI provider when api_key and default provider" do
      provider = described_class.build(api_key: "test-key")
      expect(provider).to be_a(Transcription::Providers::OpenAI)
    end

    it "returns OpenAI provider when provider_name is 'openai'" do
      provider = described_class.build(api_key: "test-key", provider_name: "openai")
      expect(provider).to be_a(Transcription::Providers::OpenAI)
    end

    it "raises ProviderNotFoundError for unsupported provider" do
      expect { described_class.build(api_key: "test-key", provider_name: "whisper") }
        .to raise_error(Transcription::ProviderNotFoundError)
    end

    it "requires api_key keyword argument" do
      expect { described_class.build }.to raise_error(ArgumentError, /api_key/)
    end

    context "when provider is assemblyai" do
      it "returns AssemblyAI provider" do
        expect(described_class.build(api_key: "dummy-key", provider_name: "assemblyai"))
          .to be_a(Transcription::Providers::AssemblyAI)
      end

      it "accepts case-insensitive variants" do
        expect(described_class.build(api_key: "dummy-key", provider_name: "AssemblyAI"))
          .to be_a(Transcription::Providers::AssemblyAI)
        expect(described_class.build(api_key: "dummy-key", provider_name: "ASSEMBLYAI"))
          .to be_a(Transcription::Providers::AssemblyAI)
      end
    end

    it "uses TRANSCRIPTION_PROVIDER env var as default provider" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("TRANSCRIPTION_PROVIDER", "openai").and_return("openai")
      provider = described_class.build(api_key: "test-key")
      expect(provider).to be_a(Transcription::Providers::OpenAI)
    end
  end
end
