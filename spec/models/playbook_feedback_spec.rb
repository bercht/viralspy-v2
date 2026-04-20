require "rails_helper"

RSpec.describe PlaybookFeedback, type: :model do
  let(:account) { create(:account) }

  describe "validations" do
    it "requires content" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        feedback = build(:playbook_feedback, account: account, playbook: playbook, content: nil)
        expect(feedback).not_to be_valid
        expect(feedback.errors[:content]).to be_present
      end
    end
  end

  describe "enums" do
    it "has correct status values" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        feedback = create(:playbook_feedback, account: account, playbook: playbook, status: :pending)
        expect(feedback.status_pending?).to be true
        feedback.status_incorporated!
        expect(feedback.status_incorporated?).to be true
        feedback.status_dismissed!
        expect(feedback.status_dismissed?).to be true
      end
    end

    it "has correct source values" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        manual = create(:playbook_feedback, account: account, playbook: playbook, source: :manual)
        expect(manual.source_manual?).to be true
        auto = create(:playbook_feedback, account: account, playbook: playbook, source: :auto)
        expect(auto.source_auto?).to be true
      end
    end
  end

  describe ".pending_for_playbook" do
    it "returns only pending feedbacks for the given playbook" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        pending = create(:playbook_feedback, account: account, playbook: playbook, status: :pending)
        incorporated = create(:playbook_feedback, account: account, playbook: playbook, status: :incorporated)
        dismissed = create(:playbook_feedback, account: account, playbook: playbook, status: :dismissed)
        result = PlaybookFeedback.pending_for_playbook(playbook)
        expect(result).to include(pending)
        expect(result).not_to include(incorporated)
        expect(result).not_to include(dismissed)
      end
    end
  end

  describe "associations" do
    it "belongs to playbook" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        feedback = create(:playbook_feedback, account: account, playbook: playbook)
        expect(feedback.playbook).to eq(playbook)
      end
    end
  end
end
