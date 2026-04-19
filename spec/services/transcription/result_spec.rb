# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcription::Result do
  describe ".success" do
    it "creates a success result with transcript and duration" do
      result = described_class.success(transcript: "Hello world", duration_seconds: 42)
      expect(result.success?).to be true
      expect(result.failure?).to be false
      expect(result.transcript).to eq("Hello world")
      expect(result.duration_seconds).to eq(42)
      expect(result.error).to be_nil
      expect(result.error_code).to be_nil
    end
  end

  describe ".failure" do
    it "creates a failure result with error and code" do
      result = described_class.failure(error: "File too large", error_code: :file_too_large)
      expect(result.success?).to be false
      expect(result.failure?).to be true
      expect(result.error).to eq("File too large")
      expect(result.error_code).to eq(:file_too_large)
      expect(result.transcript).to be_nil
    end

    it "accepts all expected error codes" do
      %i[file_too_large download_failed timeout rate_limit auth unknown].each do |code|
        result = described_class.failure(error: "err", error_code: code)
        expect(result.error_code).to eq(code)
      end
    end
  end
end
