require "rails_helper"

RSpec.describe AnalysisPlaybook, type: :model do
  let(:account) { create(:account) }

  describe "validations" do
    it "requires unique playbook per analysis" do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account)
        analysis = create(:analysis, account: account, competitor: competitor)
        playbook = create(:playbook, account: account)
        create(:analysis_playbook, analysis: analysis, playbook: playbook)
        duplicate = build(:analysis_playbook, analysis: analysis, playbook: playbook)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:playbook_id]).to be_present
      end
    end
  end

  describe "enum update_status" do
    it "defaults to playbook_update_pending" do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account)
        analysis = create(:analysis, account: account, competitor: competitor)
        playbook = create(:playbook, account: account)
        ap = create(:analysis_playbook, analysis: analysis, playbook: playbook)
        expect(ap.playbook_update_pending?).to be true
      end
    end

    it "transitions to completed" do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account)
        analysis = create(:analysis, account: account, competitor: competitor)
        playbook = create(:playbook, account: account)
        ap = create(:analysis_playbook, analysis: analysis, playbook: playbook)
        ap.playbook_update_completed!
        expect(ap.playbook_update_completed?).to be true
      end
    end

    it "transitions to failed" do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account)
        analysis = create(:analysis, account: account, competitor: competitor)
        playbook = create(:playbook, account: account)
        ap = create(:analysis_playbook, analysis: analysis, playbook: playbook)
        ap.playbook_update_failed!
        expect(ap.playbook_update_failed?).to be true
      end
    end
  end

  describe "scopes" do
    it ".playbook_update_pending returns only pending records" do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account)
        analysis = create(:analysis, account: account, competitor: competitor)
        playbook1 = create(:playbook, account: account)
        playbook2 = create(:playbook, account: account)
        pending_ap = create(:analysis_playbook, analysis: analysis, playbook: playbook1, update_status: :playbook_update_pending)
        completed_ap = create(:analysis_playbook, analysis: analysis, playbook: playbook2, update_status: :playbook_update_completed)
        result = AnalysisPlaybook.playbook_update_pending
        expect(result).to include(pending_ap)
        expect(result).not_to include(completed_ap)
      end
    end
  end

  describe "associations" do
    it "belongs to analysis and playbook" do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account)
        analysis = create(:analysis, account: account, competitor: competitor)
        playbook = create(:playbook, account: account)
        ap = create(:analysis_playbook, analysis: analysis, playbook: playbook)
        expect(ap.analysis).to eq(analysis)
        expect(ap.playbook).to eq(playbook)
      end
    end
  end
end
