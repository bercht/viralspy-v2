require "rails_helper"

RSpec.describe MediaGenerationUsageLog, type: :model do
  let(:account) { create(:account) }

  around do |example|
    ActsAsTenant.with_tenant(account) { example.run }
  end

  subject(:log) { build(:media_generation_usage_log, account: account) }

  describe "associations" do
    it "belongs to account" do
      expect(log.account).to eq(account)
    end

    it "belongs to generated_media" do
      expect(log.generated_media).to be_present
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(log).to be_valid
    end

    it "is invalid without provider" do
      log.provider = nil
      expect(log).not_to be_valid
      expect(log.errors[:provider]).to be_present
    end
  end
end
