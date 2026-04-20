require "rails_helper"

RSpec.describe GeneratedMedia, type: :model do
  let(:account) { create(:account) }

  around do |example|
    ActsAsTenant.with_tenant(account) { example.run }
  end

  subject(:media) { build(:generated_media, account: account) }

  describe "associations" do
    it "belongs to account" do
      expect(media.account).to eq(account)
    end

    it "belongs to content_suggestion" do
      expect(media.content_suggestion).to be_present
    end

    it "has many media_generation_usage_logs" do
      media.save!
      log = create(:media_generation_usage_log, account: account, generated_media: media)
      expect(media.media_generation_usage_logs).to include(log)
    end

    it "destroys media_generation_usage_logs when destroyed" do
      media.save!
      create(:media_generation_usage_log, account: account, generated_media: media)
      expect { media.destroy }.to change(MediaGenerationUsageLog, :count).by(-1)
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(media).to be_valid
    end

    it "is invalid without provider" do
      media.provider = nil
      expect(media).not_to be_valid
      expect(media.errors[:provider]).to be_present
    end

    it "is invalid without media_type" do
      media.media_type = nil
      expect(media).not_to be_valid
      expect(media.errors[:media_type]).to be_present
    end

    it "is invalid without status" do
      media.status = nil
      expect(media).not_to be_valid
      expect(media.errors[:status]).to be_present
    end
  end

  describe "enums" do
    it "has correct status values" do
      expect(described_class.statuses.keys).to match_array(%w[pending processing completed failed])
    end

    it "has correct media_type values" do
      expect(described_class.media_types.keys).to contain_exactly("avatar_video")
    end

    it "has correct provider values" do
      expect(described_class.providers.keys).to contain_exactly("heygen")
    end

    it "starts as pending" do
      expect(media.status).to eq("pending")
    end
  end

  describe "scopes" do
    let!(:old_media) { create(:generated_media, account: account, created_at: 2.days.ago) }
    let!(:new_media) { create(:generated_media, account: account, created_at: 1.hour.ago) }

    describe ".recent" do
      it "orders by created_at descending" do
        expect(described_class.recent.first).to eq(new_media)
      end
    end

    describe ".for_suggestion" do
      let(:suggestion) { old_media.content_suggestion }

      it "returns medias for the given suggestion" do
        expect(described_class.for_suggestion(suggestion)).to include(old_media)
        expect(described_class.for_suggestion(suggestion)).not_to include(new_media)
      end
    end
  end

  describe "traits" do
    it ":completed sets all completion fields" do
      media = create(:generated_media, :completed, account: account)
      expect(media.completed?).to be true
      expect(media.output_url).to be_present
      expect(media.finished_at).to be_present
    end

    it ":failed sets error_message" do
      media = create(:generated_media, :failed, account: account)
      expect(media.failed?).to be true
      expect(media.error_message).to be_present
    end
  end
end
