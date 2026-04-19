require "rails_helper"

RSpec.describe "Dashboard", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe "GET /dashboard" do
    context "sem login" do
      it "redireciona para sign_in" do
        get dashboard_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "com login" do
      before { sign_in user }

      it "retorna 200" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
      end

      it "mostra o título do dashboard" do
        get dashboard_path
        expect(response.body).to include("Dashboard")
      end

      it "mostra até 5 competitors recentes do tenant" do
        competitors = ActsAsTenant.with_tenant(account) { create_list(:competitor, 6, account: account) }
        get dashboard_path
        expect(response.body).to include("@#{competitors.last.instagram_handle}")
        expect(response.body).not_to include("@#{competitors.first.instagram_handle}")
      end

      it "mostra analyses recentes do tenant" do
        competitor = ActsAsTenant.with_tenant(account) { create(:competitor, account: account) }
        ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) }
        get dashboard_path
        expect(response.body).to include(I18n.t("analysis.status.pending"))
      end

      it "não mostra competitors de outra account" do
        other_account = create(:account)
        other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
        ActsAsTenant.with_tenant(account) { create(:competitor, account: account) }
        get dashboard_path
        expect(response.body).not_to include("@#{other_competitor.instagram_handle}")
      end
    end
  end
end
