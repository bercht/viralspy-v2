require "rails_helper"

RSpec.describe PlaybookSuggestion, type: :model do
  let(:account) { create(:account) }
  let(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

  describe "validations" do
    it "requer content_type" do
      ActsAsTenant.with_tenant(account) do
        suggestion = build(:playbook_suggestion, account: account, playbook: playbook, content_type: nil)
        expect(suggestion).not_to be_valid
        expect(suggestion.errors[:content_type]).to be_present
      end
    end

    it "requer status" do
      ActsAsTenant.with_tenant(account) do
        suggestion = build(:playbook_suggestion, account: account, playbook: playbook, status: nil)
        expect(suggestion).not_to be_valid
      end
    end
  end

  describe "enums" do
    it "tem status corretos" do
      expect(described_class.statuses).to eq("draft" => 0, "saved" => 1, "discarded" => 2)
    end

    it "tem content_type corretos" do
      expect(described_class.content_types).to eq(
        "reel" => "reel",
        "carousel" => "carousel",
        "image" => "image",
        "story" => "story"
      )
    end
  end

  describe "tenant scoping" do
    it "não acessa sugestões de outra account" do
      other_account = create(:account)
      other_playbook = ActsAsTenant.with_tenant(other_account) { create(:playbook, account: other_account) }
      ActsAsTenant.with_tenant(other_account) do
        create(:playbook_suggestion, account: other_account, playbook: other_playbook)
      end

      ActsAsTenant.with_tenant(account) do
        expect(PlaybookSuggestion.count).to eq(0)
      end
    end
  end

  describe "scopes" do
    it "recent ordena por created_at desc" do
      ActsAsTenant.with_tenant(account) do
        old = create(:playbook_suggestion, account: account, playbook: playbook, created_at: 2.days.ago)
        new = create(:playbook_suggestion, account: account, playbook: playbook, created_at: 1.day.ago)
        expect(PlaybookSuggestion.recent.first).to eq(new)
      end
    end

    it "visible exclui descartados" do
      ActsAsTenant.with_tenant(account) do
        draft = create(:playbook_suggestion, account: account, playbook: playbook, status: :draft)
        saved = create(:playbook_suggestion, account: account, playbook: playbook, status: :saved)
        discarded = create(:playbook_suggestion, account: account, playbook: playbook, status: :discarded)
        visible = PlaybookSuggestion.visible
        expect(visible).to include(draft, saved)
        expect(visible).not_to include(discarded)
      end
    end
  end
end
