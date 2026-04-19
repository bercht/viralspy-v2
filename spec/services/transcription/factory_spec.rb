# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::Factory do
  describe ".build" do
    around do |example|
      original = ENV["OPENAI_API_KEY"]
      ENV["OPENAI_API_KEY"] = "test-key" if original.blank?
      example.run
    ensure
      ENV["OPENAI_API_KEY"] = original
    end

    it "returns OpenAI provider by default" do
      provider = described_class.build
      expect(provider).to be_a(Transcription::Providers::OpenAI)
    end

    it "returns OpenAI provider for 'openai'" do
      provider = described_class.build("openai")
      expect(provider).to be_a(Transcription::Providers::OpenAI)
    end

    it "raises ProviderNotFoundError for unsupported provider" do
      expect { described_class.build("whisper") }.to raise_error(Transcription::ProviderNotFoundError)
    end

    context "when provider is assemblyai" do
      around do |example|
        original = ENV["ASSEMBLYAI_API_KEY"]
        ENV["ASSEMBLYAI_API_KEY"] = "dummy-assemblyai-key"
        example.run
      ensure
        ENV["ASSEMBLYAI_API_KEY"] = original
      end

      it "returns AssemblyAI provider" do
        expect(described_class.build("assemblyai")).to be_a(Transcription::Providers::AssemblyAI)
      end

      it "accepts case-insensitive variants" do
        expect(described_class.build("AssemblyAI")).to be_a(Transcription::Providers::AssemblyAI)
        expect(described_class.build("ASSEMBLYAI")).to be_a(Transcription::Providers::AssemblyAI)
      end
    end

    it "uses TRANSCRIPTION_PROVIDER env var as default" do
      allow(ENV).to receive(:fetch).with("TRANSCRIPTION_PROVIDER", "openai").and_return("openai")
      provider = described_class.build
      expect(provider).to be_a(Transcription::Providers::OpenAI)
    end
  end
end
