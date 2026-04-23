require "rails_helper"

# skip_tenant: true — allows the controller's set_current_tenant to apply
# full acts_as_tenant scoping during requests (without_tenant would bypass it)
RSpec.describe "Analyses", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account, niche: "Marketing imobiliário") } }
  let!(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }
  let(:other_account) { create(:account) }
  let(:other_competitor) { ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) } }

  before { sign_in user }

  def stub_ready_for_analysis
    allow_any_instance_of(Account).to receive(:ready_for_analysis?).and_return(true)
  end

  describe "GET /competitors/:competitor_id/analyses/new" do
    context "com credenciais configuradas" do
      before { stub_ready_for_analysis }

      it "renderiza o form de nova análise" do
        get new_competitor_analysis_path(competitor)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("analyses.form.submit"))
      end

      it "retorna 404 para competitor de outra account" do
        get new_competitor_analysis_path(other_competitor)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "quando competitor não tem nicho" do
      before do
        stub_ready_for_analysis
        competitor.update!(niche: nil)
      end

      it "redireciona para edição com flash de alerta" do
        get new_competitor_analysis_path(competitor)

        expect(response).to redirect_to(edit_competitor_path(competitor))
        expect(flash[:alert]).to eq(I18n.t("analyses.errors.competitor_niche_missing"))
      end
    end

    context "quando account não tem playbooks" do
      before do
        stub_ready_for_analysis
        ActsAsTenant.with_tenant(account) { account.playbooks.destroy_all }
      end

      it "redireciona para criação de playbook com flash de alerta" do
        get new_competitor_analysis_path(competitor)

        expect(response).to redirect_to(new_playbook_path)
        expect(flash[:alert]).to eq(I18n.t("analyses.errors.no_playbook"))
      end
    end

    context "sem credenciais configuradas" do
      before do
        allow_any_instance_of(Account).to receive(:ready_for_analysis?).and_return(false)
        allow_any_instance_of(Account).to receive(:missing_credentials_for_analysis).and_return([ :openai, :assemblyai ])
      end

      it "redireciona para settings/llm_preferences com flash listando providers" do
        get new_competitor_analysis_path(competitor)
        expect(response).to redirect_to(edit_settings_llm_preferences_path)
        expect(flash[:alert]).to include("OpenAI")
        expect(flash[:alert]).to include("AssemblyAI")
      end
    end
  end

  describe "POST /competitors/:competitor_id/analyses" do
    before do
      stub_ready_for_analysis
      allow(Analyses::RunAnalysisWorker).to receive(:perform_async)
    end

    it "cria analysis em :pending e enfileira RunAnalysisWorker" do
      expect {
        post competitor_analyses_path(competitor), params: { analysis: { max_posts: 80 } }
      }.to change { Analysis.unscoped.count }.by(1)

      expect(Analyses::RunAnalysisWorker).to have_received(:perform_async)
      analysis = Analysis.unscoped.last
      expect(analysis.status).to eq("pending")
      expect(analysis.max_posts).to eq(80)
      expect(analysis.account_id).to eq(account.id)
    end

    it "redireciona para o show da analysis criada" do
      post competitor_analyses_path(competitor), params: { analysis: { max_posts: 50 } }
      analysis = Analysis.unscoped.last
      expect(response).to redirect_to(competitor_analysis_path(competitor, analysis))
    end

    it "usa max_posts padrão quando não informado" do
      post competitor_analyses_path(competitor), params: { analysis: {} }
      expect(Analysis.unscoped.last.max_posts).to eq(50)
    end

    it "re-renderiza new com 422 quando max_posts fora do intervalo" do
      expect {
        post competitor_analyses_path(competitor), params: { analysis: { max_posts: 5 } }
      }.not_to change { Analysis.unscoped.count }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "retorna 404 para competitor de outra account" do
      post competitor_analyses_path(other_competitor), params: { analysis: { max_posts: 50 } }
      expect(response).to have_http_status(:not_found)
    end

    it "redireciona quando credentials ausentes" do
      allow_any_instance_of(Account).to receive(:ready_for_analysis?).and_return(false)
      allow_any_instance_of(Account).to receive(:missing_credentials_for_analysis).and_return([ :openai ])

      expect {
        post competitor_analyses_path(competitor), params: { analysis: { max_posts: 50 } }
      }.not_to change { Analysis.unscoped.count }

      expect(response).to redirect_to(edit_settings_llm_preferences_path)
    end

    context "quando competitor não tem nicho" do
      before { competitor.update!(niche: nil) }

      it "bloqueia criação e redireciona para edição" do
        expect {
          post competitor_analyses_path(competitor), params: { analysis: { max_posts: 50 } }
        }.not_to change { Analysis.unscoped.count }

        expect(response).to redirect_to(edit_competitor_path(competitor))
        expect(flash[:alert]).to eq(I18n.t("analyses.errors.competitor_niche_missing"))
      end
    end

    context "quando account não tem playbooks" do
      before { ActsAsTenant.with_tenant(account) { account.playbooks.destroy_all } }

      it "bloqueia criação e redireciona para novo playbook" do
        expect {
          post competitor_analyses_path(competitor), params: { analysis: { max_posts: 50 } }
        }.not_to change { Analysis.unscoped.count }

        expect(response).to redirect_to(new_playbook_path)
        expect(flash[:alert]).to eq(I18n.t("analyses.errors.no_playbook"))
      end
    end

    context "com playbook_ids selecionados" do
      let(:playbook_2) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

      it "cria AnalysisPlaybook para cada playbook selecionado com status pending" do
        post competitor_analyses_path(competitor),
             params: { analysis: { max_posts: 20, playbook_ids: [ playbook.id, playbook_2.id ] } }

        ActsAsTenant.with_tenant(account) do
          analysis = account.analyses.last
          expect(analysis.playbooks).to include(playbook, playbook_2)
          expect(analysis.analysis_playbooks.count).to eq(2)
          expect(analysis.analysis_playbooks.all?(&:playbook_update_pending?)).to be true
        end
      end

      it "cria análise sem AnalysisPlaybooks quando nenhum selecionado" do
        post competitor_analyses_path(competitor),
             params: { analysis: { max_posts: 20, playbook_ids: [] } }

        analysis = Analysis.unscoped.last
        expect(analysis.analysis_playbooks).to be_empty
      end

      it "não vincula Playbook de outro tenant" do
        other_playbook = ActsAsTenant.with_tenant(other_account) { create(:playbook, account: other_account) }

        expect {
          post competitor_analyses_path(competitor),
               params: { analysis: { max_posts: 20, playbook_ids: [ other_playbook.id ] } }
        }.to change { Analysis.unscoped.count }.by(1)

        ActsAsTenant.with_tenant(account) do
          analysis = account.analyses.last
          expect(analysis.playbooks).not_to include(other_playbook)
        end
      end
    end
  end

  describe "GET /competitors/:competitor_id/analyses/:id" do
    context "status pending" do
      let!(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor, status: :pending) } }

      it "retorna 200 e renderiza in_progress" do
        get competitor_analysis_path(competitor, analysis)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("analyses.status.pending"))
      end

      it "não requer credentials configuradas" do
        allow_any_instance_of(Account).to receive(:ready_for_analysis?).and_return(false)
        get competitor_analysis_path(competitor, analysis)
        expect(response).to have_http_status(:ok)
      end
    end

    context "status scraping" do
      let!(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, :scraping, account: account, competitor: competitor) } }

      it "renderiza in_progress com texto do step scraping" do
        get competitor_analysis_path(competitor, analysis)
        expect(response.body).to include(I18n.t("analyses.status.scraping"))
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

  describe "GET /competitors/:competitor_id/analyses/:id/export_top_posts" do
    let!(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, :completed, account: account, competitor: competitor) } }

    it "retorna 200 com Content-Type text/plain" do
      get export_top_posts_competitor_analysis_path(competitor, analysis)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/plain")
    end

    it "inclui Content-Disposition attachment com filename correto" do
      get export_top_posts_competitor_analysis_path(competitor, analysis)
      disposition = response.headers["Content-Disposition"]
      expect(disposition).to include("attachment")
      expect(disposition).to include("viralspy_top_posts_#{competitor.instagram_handle}_#{analysis.id}.txt")
    end

    it "retorna 404 para analysis de outra account" do
      other_analysis = ActsAsTenant.with_tenant(other_account) do
        create(:analysis, :completed, account: other_account, competitor: other_competitor)
      end
      get export_top_posts_competitor_analysis_path(other_competitor, other_analysis)
      expect(response).to have_http_status(:not_found)
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        get export_top_posts_competitor_analysis_path(competitor, analysis)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /competitors/:competitor_id/analyses/:id/extend_expiry" do
    let!(:analysis) do
      ActsAsTenant.with_tenant(account) do
        create(:analysis, :completed, account: account, competitor: competitor,
               expires_at: 5.days.from_now)
      end
    end

    it "estende expires_at em 30 dias e retorna turbo_stream" do
      original_expiry = analysis.expires_at
      post extend_expiry_competitor_analysis_path(competitor, analysis),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(analysis.reload.expires_at).to be_within(5.seconds).of(original_expiry + 30.days)
    end

    it "retorna 404 para analysis de outro tenant" do
      other_analysis = ActsAsTenant.with_tenant(other_account) do
        create(:analysis, :completed, account: other_account, competitor: other_competitor,
               expires_at: 5.days.from_now)
      end
      post extend_expiry_competitor_analysis_path(other_competitor, other_analysis),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:not_found)
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        post extend_expiry_competitor_analysis_path(competitor, analysis)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /competitors/:competitor_id/analyses/:id/discard" do
    let!(:analysis) do
      ActsAsTenant.with_tenant(account) do
        create(:analysis, :completed, account: account, competitor: competitor,
               expires_at: 1.day.ago)
      end
    end

    it "destrói a análise e retorna turbo_stream" do
      expect {
        delete discard_competitor_analysis_path(competitor, analysis),
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change { Analysis.unscoped.count }.by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "destrói os posts associados" do
      ActsAsTenant.with_tenant(account) do
        create(:post, analysis: analysis, account: account)
        expect {
          delete discard_competitor_analysis_path(competitor, analysis),
                 headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change { Post.unscoped.count }.by(-1)
      end
    end

    it "NÃO destrói o playbook associado" do
      delete discard_competitor_analysis_path(competitor, analysis),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(Playbook.unscoped.find_by(id: playbook.id)).to be_present
    end

    it "retorna 404 para analysis de outro tenant" do
      other_analysis = ActsAsTenant.with_tenant(other_account) do
        create(:analysis, :completed, account: other_account, competitor: other_competitor,
               expires_at: 1.day.ago)
      end
      delete discard_competitor_analysis_path(other_competitor, other_analysis),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:not_found)
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        delete discard_competitor_analysis_path(competitor, analysis)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
