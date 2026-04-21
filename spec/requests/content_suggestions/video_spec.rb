require "rails_helper"

RSpec.describe "ContentSuggestions::Video", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }
  let(:analysis) do
    ActsAsTenant.with_tenant(account) { create(:analysis, :completed, account: account, competitor: competitor) }
  end
  let(:suggestion) do
    ActsAsTenant.with_tenant(account) { create(:content_suggestion, account: account, analysis: analysis) }
  end

  before { sign_in user }

  describe "GET /content_suggestions/:id/video/new" do
    it "retorna 200 para suggestion do próprio tenant" do
      get new_content_suggestion_video_path(suggestion)
      expect(response).to have_http_status(:ok)
    end

    it "exibe campo de script" do
      get new_content_suggestion_video_path(suggestion)
      expect(response.body).to include("Script do vídeo")
    end

    it "exibe o hook da suggestion no script pré-preenchido" do
      get new_content_suggestion_video_path(suggestion)
      expect(response.body).to include(suggestion.hook)
    end

    context "sem autenticação" do
      before { sign_out user }

      it "redireciona para login" do
        get new_content_suggestion_video_path(suggestion)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "com suggestion de outro tenant" do
      let(:other_account) { create(:account) }
      let(:other_suggestion) do
        ActsAsTenant.with_tenant(other_account) { create(:content_suggestion, account: other_account) }
      end

      it "retorna 404" do
        get new_content_suggestion_video_path(other_suggestion)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
