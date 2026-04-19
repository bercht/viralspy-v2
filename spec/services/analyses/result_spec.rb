require "rails_helper"

RSpec.describe Analyses::Result do
  describe ".success" do
    it "creates a success result" do
      result = described_class.success

      expect(result).to be_success
      expect(result).not_to be_failure
    end

    it "stores data when provided" do
      result = described_class.success(data: { count: 5 })

      expect(result.data).to eq({ count: 5 })
    end

    it "defaults data to empty hash" do
      result = described_class.success

      expect(result.data).to eq({})
    end
  end

  describe ".failure" do
    it "creates a failure result" do
      result = described_class.failure(error: "something went wrong")

      expect(result).to be_failure
      expect(result).not_to be_success
    end

    it "stores the error message" do
      result = described_class.failure(error: "something went wrong")

      expect(result.error).to eq("something went wrong")
    end

    it "stores the error_code when provided" do
      result = described_class.failure(error: "oops", error_code: :scraping_failed)

      expect(result.error_code).to eq(:scraping_failed)
    end

    it "defaults error_code to nil" do
      result = described_class.failure(error: "oops")

      expect(result.error_code).to be_nil
    end
  end
end
