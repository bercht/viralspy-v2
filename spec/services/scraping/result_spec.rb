require "rails_helper"

RSpec.describe Scraping::Result do
  describe ".success" do
    it "creates a successful result" do
      result = described_class.success(
        posts: [ { id: "a" } ],
        profile_data: { handle: "foo" },
        run_id: "run_123"
      )

      expect(result).to be_success
      expect(result).not_to be_failure
      expect(result.posts).to eq([ { id: "a" } ])
      expect(result.profile_data).to eq({ handle: "foo" })
      expect(result.run_id).to eq("run_123")
      expect(result.error).to be_nil
    end
  end

  describe ".failure" do
    it "creates a failed result" do
      result = described_class.failure(
        error: :profile_not_found,
        message: "handle not found",
        run_id: "run_456"
      )

      expect(result).to be_failure
      expect(result).not_to be_success
      expect(result.posts).to eq([])
      expect(result.profile_data).to eq({})
      expect(result.error).to eq(:profile_not_found)
      expect(result.message).to eq("handle not found")
      expect(result.run_id).to eq("run_456")
    end

    it "allows nil run_id (failure before any run was created)" do
      result = described_class.failure(error: :timeout)
      expect(result.run_id).to be_nil
    end
  end
end
