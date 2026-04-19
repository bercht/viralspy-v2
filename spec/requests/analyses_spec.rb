require "rails_helper"

# skip_tenant: true — allows the controller's set_current_tenant to apply
# full acts_as_tenant scoping during requests (without_tenant would bypass it)
RSpec.describe "Analyses", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }
  let(:other_account) { create(:account) }
  let(:other_competitor) { ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) } }

  before { sign_in user }

  describe "POST /competitors/:competitor_id/analyses" do
    before { allow(Analyses::RunAnalysisWorker).to receive(:perform_async) }

    it "cria analysis em :pending e enfileira RunAnalysisWorker" do
      expect {
        post competitor_analyses_path(competitor)
      }.to change { Analysis.unscoped.count }.by(1)

      expect(Analyses::RunAnalysisWorker).to have_received(:perform_async)
      expect(Analysis.unscoped.last.status).to eq("pending")
    end

    it "redireciona para o show da analysis criada" do
      post competitor_analyses_path(competitor)
      analysis = Analysis.unscoped.last
      expect(response).to redirect_to(competitor_analysis_path(competitor, analysis))
    end

    it "retorna 404 para competitor de outra account" do
      post competitor_analyses_path(other_competitor)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /competitors/:competitor_id/analyses/:id" do
    context "status pending" do
      let!(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor, status: :pending) } }

      it "retorna 200 e renderiza in_progress" do
        get competitor_analysis_path(competitor, analysis)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("analyses.show.in_progress.pending"))
      end
    end

    context "status scraping" do
      let!(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, :scraping, account: account, competitor: competitor) } }

      it "renderiza in_progress com texto de scraping" do
        get competitor_analysis_path(competitor, analysis)
        expect(response.body).to include(I18n.t("analyses.show.in_progress.scraping"))
      end
    end

    context "status completed" do
      let!(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, :completed, account: account, competitor: competitor) } }

      it "retorna 200 e renderiza métricas" do
        get competitor_analysis_path(competitor, analysis)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("analyses.show.profile_metrics.title"))
      end
    end

    context "status failed" do
      let!(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, :failed, account: account, competitor: competitor) } }

      it "renderiza o estado de falha com error_message" do
        get competitor_analysis_path(competitor, analysis)
        expect(response.body).to include(I18n.t("analyses.show.failed.title"))
        expect(response.body).to include(analysis.error_message)
      end
    end

    it "retorna 404 para analysis de outra account" do
      other_analysis = ActsAsTenant.with_tenant(other_account) do
        create(:analysis, account: other_account, competitor: other_competitor)
      end
      get competitor_analysis_path(other_competitor, other_analysis)
      expect(response).to have_http_status(:not_found)
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        analysis = ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) }
        get competitor_analysis_path(competitor, analysis)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
