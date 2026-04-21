require "rails_helper"

RSpec.describe "End-to-end — happy path do usuário", type: :system do
  def setup_completed_analysis(analysis)
    analysis.update!(
      status: :completed,
      finished_at: Time.current,
      posts_scraped_count: 10,
      posts_analyzed_count: 8,
      profile_metrics: {
        "posts_per_week" => 3.5,
        "avg_likes_per_post" => 800,
        "avg_comments_per_post" => 40,
        "avg_engagement_rate" => 0.035,
        "content_mix" => { "reel" => 0.6, "carousel" => 0.3, "image" => 0.1 },
        "top_hashtags" => %w[imoveis poa moradia]
      }
    )

    ActsAsTenant.with_tenant(analysis.account) do
      create(:post, :selected, :reel,
        account: analysis.account,
        analysis: analysis,
        competitor: analysis.competitor,
        caption: "Post selecionado de teste",
        likes_count: 500,
        comments_count: 30,
        quality_score: 8.5)

      create(:content_suggestion, :reel,
        account: analysis.account,
        analysis: analysis,
        position: 1,
        hook: "Hook de teste end-to-end",
        caption_draft: "Caption de teste",
        suggested_hashtags: %w[teste],
        status: :draft,
        format_details: { "duration_seconds" => 30, "structure" => %w[hook cta] })
    end
  end

  describe "gate de credentials" do
    it "redireciona pra /settings/llm_preferences/edit ao tentar criar análise sem credenciais" do
      user = create(:user)
      competitor = ActsAsTenant.with_tenant(user.account) do
        create(:competitor, account: user.account, instagram_handle: "concorrente_teste")
      end

      login_as(user, scope: :user)
      visit new_competitor_analysis_path(competitor)

      expect(page).to have_current_path(edit_settings_llm_preferences_path, ignore_query: true)
      expect(page).to have_content(I18n.t("api_credentials.missing.cta", default: "Configure"))
    end
  end

  describe "happy path completo" do
    it "cria competitor → credenciais → análise → vê resultado → salva sugestão" do
      user = create(:user)
      account = user.account

      login_as(user, scope: :user)

      # Dashboard mostra empty state
      visit dashboard_path
      expect(page).to have_content(I18n.t("dashboard.empty.title"))
      click_link I18n.t("dashboard.empty.cta")

      # Cria competitor
      expect(page).to have_current_path(new_competitor_path, ignore_query: true)
      fill_in "competitor_instagram_handle", with: "concorrente123"
      click_button I18n.t("competitors.form.submit")

      expect(page).to have_content("concorrente123")

      # Empty state de análises
      expect(page).to have_content(I18n.t("competitors.show.no_analyses.title"))

      # Tentar iniciar análise → gate de credentials
      click_link I18n.t("competitors.show.no_analyses.cta")
      expect(page).to have_current_path(edit_settings_llm_preferences_path, ignore_query: true)

      # Configura credenciais via factory
      competitor = ActsAsTenant.with_tenant(account) do
        account.competitors.find_by(instagram_handle: "concorrente123")
      end

      ActsAsTenant.with_tenant(account) do
        create(:api_credential, :openai, :valid, account: account)
        create(:api_credential, :anthropic, :valid, account: account)
        create(:api_credential, :assemblyai, :valid, account: account)
      end

      # Agora deve conseguir acessar o form de análise
      visit new_competitor_analysis_path(competitor)
      expect(page).to have_current_path(new_competitor_analysis_path(competitor), ignore_query: true)

      # Stub do worker para não executar pipeline real
      allow(Analyses::RunAnalysisWorker).to receive(:perform_async)

      click_button I18n.t("analyses.form.submit")

      analysis = ActsAsTenant.with_tenant(account) do
        competitor.analyses.order(created_at: :desc).first
      end
      expect(analysis).to be_present

      # Popula análise com dados de completed (dentro do tenant para evitar NoTenantSet no broadcast)
      ActsAsTenant.with_tenant(account) do
        setup_completed_analysis(analysis)
      end

      # Visita a página de resultado
      visit competitor_analysis_path(competitor, analysis)

      expect(page).to have_content(I18n.t("analyses.show.profile_metrics.title"))
      expect(page).to have_content("3.5")
      expect(page).to have_content(I18n.t("analyses.show.suggestions.title"))
      expect(page).to have_content("Hook de teste end-to-end")

      # Salva sugestão via button_to (Turbo não executa em rack_test, mas o form submit funciona)
      suggestion = ActsAsTenant.with_tenant(account) do
        analysis.content_suggestions.first
      end

      within "##{ActionView::RecordIdentifier.dom_id(suggestion)}" do
        click_button I18n.t("analyses.show.suggestions.save")
      end

      expect(suggestion.reload.status).to eq("saved")
    end
  end

  describe "empty states — verificação de presença" do
    it "mostra empty state em /competitors quando sem competitors" do
      login_as(create(:user), scope: :user)
      visit competitors_path
      expect(page).to have_content(I18n.t("competitors.empty.title"))
    end

    it "mostra empty state educativo em /settings/api_keys quando sem chaves" do
      login_as(create(:user), scope: :user)
      visit settings_api_keys_path
      expect(page).to have_content(I18n.t("settings.api_keys.empty.title"))
    end

    it "mostra estado failed com CTA de retry" do
      user = create(:user)
      competitor = ActsAsTenant.with_tenant(user.account) do
        create(:competitor, account: user.account)
      end
      analysis = ActsAsTenant.with_tenant(user.account) do
        create(:analysis, :failed, account: user.account, competitor: competitor)
      end

      login_as(user, scope: :user)
      visit competitor_analysis_path(competitor, analysis)

      expect(page).to have_content(I18n.t("analyses.show.failed.title"))
      expect(page).to have_link(I18n.t("analyses.show.failed.retry"))
    end
  end
end
