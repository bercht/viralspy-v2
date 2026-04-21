require "rails_helper"

RSpec.describe "Settings::LlmPreferences", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before { sign_in user }

  describe "GET /settings/llm_preferences/edit" do
    it "renderiza a tela de preferências de provider" do
      get edit_settings_llm_preferences_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("settings.llm_preferences.title"))
      expect(response.body).to include(I18n.t("settings.navigation.api_keys"))
      expect(response.body).to include(I18n.t("settings.navigation.llm_preferences"))
    end

    it "exibe apenas providers com credential ativa e validada" do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, :valid, account: account, provider: "anthropic")
        create(:api_credential, :valid, account: account, provider: "assemblyai")
        create(:api_credential, :inactive, account: account, provider: "openai")
      end

      get edit_settings_llm_preferences_path

      html = Nokogiri::HTML(response.body)
      analysis_values = html.css('select[name="llm_preferences[analysis_provider]"] option').map { |option| option["value"] }
      transcription_values = html.css('select[name="llm_preferences[transcription_provider]"] option').map { |option| option["value"] }

      expect(analysis_values).to contain_exactly("anthropic")
      expect(transcription_values).to contain_exactly("assemblyai")
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        get edit_settings_llm_preferences_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /settings/llm_preferences" do
    it "persiste preferências no account.llm_preferences" do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, :valid, account: account, provider: "anthropic")
        create(:api_credential, :valid, account: account, provider: "assemblyai")
      end

      patch settings_llm_preferences_path, params: {
        llm_preferences: {
          transcription_provider: "assemblyai",
          transcription_model: "default",
          analysis_provider: "anthropic",
          analysis_model: "claude-sonnet-4-6",
          generation_provider: "anthropic",
          generation_model: "claude-sonnet-4-6"
        }
      }

      expect(response).to redirect_to(edit_settings_llm_preferences_path)
      expect(flash[:notice]).to eq(I18n.t("settings.llm_preferences.flash.updated"))

      prefs = account.reload.llm_preferences
      expect(prefs["transcription_provider"]).to eq("assemblyai")
      expect(prefs["analysis_provider"]).to eq("anthropic")
      expect(prefs["generation_provider"]).to eq("anthropic")
      expect(prefs["analysis_model"]).to eq("claude-sonnet-4-6")
      expect(prefs["generation_model"]).to eq("claude-sonnet-4-6")
    end
  end
end
