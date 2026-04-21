require "rails_helper"

RSpec.describe "PlaybookFeedbacks", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let!(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

  before { sign_in user }

  describe "POST /playbooks/:playbook_id/playbook_feedbacks" do
    it "cria feedback e redireciona" do
      expect {
        post playbook_playbook_feedbacks_path(playbook),
          params: { playbook_feedback: { content: "Aprendi algo novo." } }
      }.to change { PlaybookFeedback.unscoped.count }.by(1)

      feedback = PlaybookFeedback.unscoped.order(:created_at).last

      expect(feedback.source).to eq("manual")
      expect(response).to redirect_to(playbook_path(playbook))
    end

    it "rejeita content vazio" do
      expect {
        post playbook_playbook_feedbacks_path(playbook),
          params: { playbook_feedback: { content: "" } }
      }.not_to change { PlaybookFeedback.unscoped.count }
    end
  end

  describe "PATCH /playbook_feedbacks/:id/incorporate" do
    let!(:feedback) { ActsAsTenant.with_tenant(account) { create(:playbook_feedback, account: account, playbook: playbook, status: :pending) } }

    it "marca como incorporated e redireciona" do
      patch incorporate_playbook_feedback_path(feedback)
      expect(feedback.reload.status_incorporated?).to be true
      expect(response).to be_redirect
    end
  end

  describe "PATCH /playbook_feedbacks/:id/dismiss" do
    let!(:feedback) { ActsAsTenant.with_tenant(account) { create(:playbook_feedback, account: account, playbook: playbook, status: :pending) } }

    it "marca como dismissed e redireciona" do
      patch dismiss_playbook_feedback_path(feedback)
      expect(feedback.reload.status_dismissed?).to be true
      expect(response).to be_redirect
    end
  end
end
