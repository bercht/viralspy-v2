# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::Factory do
  describe ".build" do
    it "returns OpenAI provider when provider is 'openai'" do
      provider = described_class.build(provider: "openai", api_key: "test-key")
      expect(provider).to be_a(Transcription::Providers::OpenAI)
    end

    it "returns OpenAI provider when provider is :openai (symbol)" do
      provider = described_class.build(provider: :openai, api_key: "test-key")
      expect(provider).to be_a(Transcription::Providers::OpenAI)
    end

    it "raises ProviderNotFoundError for unsupported provider" do
      expect { described_class.build(provider: "whisper", api_key: "test-key") }
        .to raise_error(Transcription::ProviderNotFoundError)
    end

    it "requires provider: keyword argument" do
      expect { described_class.build(api_key: "test-key") }
        .to raise_error(ArgumentError, /provider/)
    end

    it "requires api_key: keyword argument" do
      expect { described_class.build(provider: "openai") }
        .to raise_error(ArgumentError, /api_key/)
    end

    context "when provider is assemblyai" do
      it "returns AssemblyAI provider" do
        expect(described_class.build(provider: "assemblyai", api_key: "dummy-key"))
          .to be_a(Transcription::Providers::AssemblyAI)
      end

      it "accepts case-insensitive variants" do
        expect(described_class.build(provider: "AssemblyAI", api_key: "dummy-key"))
          .to be_a(Transcription::Providers::AssemblyAI)
        expect(described_class.build(provider: "ASSEMBLYAI", api_key: "dummy-key"))
          .to be_a(Transcription::Providers::AssemblyAI)
      end

      it "accepts :assemblyai symbol" do
        expect(described_class.build(provider: :assemblyai, api_key: "dummy-key"))
          .to be_a(Transcription::Providers::AssemblyAI)
      end
    end
  end
end
