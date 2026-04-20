# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiCredentials::Result do
  describe ".success" do
    it "returns a verified success result" do
      result = described_class.success
      expect(result).to be_success
      expect(result.status).to eq(:verified)
      expect(result.message).to eq("API key validated successfully")
    end

    it "accepts custom message" do
      result = described_class.success(message: "custom ok")
      expect(result.message).to eq("custom ok")
    end
  end

  describe ".failure" do
    it "returns a failure with given status" do
      result = described_class.failure(status: :failed, message: "nope")
      expect(result).to be_failure
      expect(result.status).to eq(:failed)
      expect(result.message).to eq("nope")
    end

    it "is not success for any non-:verified status" do
      [ :failed, :quota_exceeded, :unknown ].each do |s|
        result = described_class.failure(status: s, message: "x")
        expect(result).to be_failure
        expect(result).not_to be_success
      end
    end
  end
end
