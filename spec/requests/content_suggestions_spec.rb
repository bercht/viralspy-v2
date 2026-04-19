require "rails_helper"

# skip_tenant: true — allows the controller's set_current_tenant to apply
# full acts_as_tenant scoping during requests (without_tenant would bypass it)
RSpec.describe "ContentSuggestions", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }
  let(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, :completed, account: account, competitor: competitor) } }
  let(:suggestion) { ActsAsTenant.with_tenant(account) { create(:content_suggestion, account: account, analysis: analysis, status: :draft) } }
  let(:other_account) { create(:account) }

  before { sign_in user }

  describe "PATCH /content_suggestions/:id" do
    it "atualiza status para saved e redireciona" do
      patch content_suggestion_path(suggestion),
            params: { content_suggestion: { status: "saved" } }

      expect(suggestion.reload.status).to eq("saved")
      expect(response).to redirect_to(competitor_analysis_path(competitor, analysis))
    end

    it "atualiza status para discarded e redireciona" do
      patch content_suggestion_path(suggestion),
            params: { content_suggestion: { status: "discarded" } }

      expect(suggestion.reload.status).to eq("discarded")
      expect(response).to redirect_to(competitor_analysis_path(competitor, analysis))
    end

    it "não atualiza com status inválido e redireciona com alert" do
      original_status = suggestion.status
      patch content_suggestion_path(suggestion),
            params: { content_suggestion: { status: "invalid_status" } }

      expect(suggestion.reload.status).to eq(original_status)
      expect(response).to redirect_to(competitor_analysis_path(competitor, analysis))
    end

    it "retorna 404 para suggestion de outra account" do
      other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
      other_analysis = ActsAsTenant.with_tenant(other_account) { create(:analysis, :completed, account: other_account, competitor: other_competitor) }
      other_suggestion = ActsAsTenant.with_tenant(other_account) { create(:content_suggestion, account: other_account, analysis: other_analysis) }

      patch content_suggestion_path(other_suggestion),
            params: { content_suggestion: { status: "saved" } }
      expect(response).to have_http_status(:not_found)
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        patch content_suggestion_path(suggestion),
              params: { content_suggestion: { status: "saved" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
