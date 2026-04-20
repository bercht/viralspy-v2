require "rails_helper"

RSpec.describe "Settings::ApiKeys", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:other_account) { create(:account) }

  before { sign_in user }

  describe "GET /settings/api_keys" do
    it "renderiza tela com 3 providers" do
      get settings_api_keys_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OpenAI")
      expect(response.body).to include("Anthropic")
      expect(response.body).to include("AssemblyAI")
    end

    it "mostra badge 'não configurada' quando não há credential" do
      get settings_api_keys_path
      expect(response.body).to include(I18n.t("settings.api_keys.status.not_configured"))
    end

    it "mostra status verified quando credential existe" do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, :valid, account: account, provider: "openai")
      end
      get settings_api_keys_path
      expect(response.body).to include(I18n.t("settings.api_keys.status.verified"))
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        get settings_api_keys_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /settings/api_keys/providers/:provider" do
    before do
      allow(ApiCredentials::ValidateService).to receive(:call) do |cred|
        cred.update!(last_validation_status: :verified, last_validated_at: Time.current)
        ApiCredentials::Result.success
      end
    end

    it "cria credential e roda validação" do
      expect {
        post create_for_settings_api_keys_path("openai"), params: {
          api_credential: { api_key: "sk-test-abc123" }
        }
      }.to change { ApiCredential.unscoped.count }.by(1)

      expect(ApiCredentials::ValidateService).to have_received(:call)
      expect(response).to redirect_to(settings_api_keys_path)
    end

    it "redireciona com alert para provider inválido" do
      post create_for_settings_api_keys_path("invalid_provider"), params: {
        api_credential: { api_key: "sk-test" }
      }
      expect(response).to redirect_to(settings_api_keys_path)
      expect(flash[:alert]).to eq(I18n.t("settings.api_keys.flash.invalid_provider"))
    end

    it "não cria quando api_key é vazio" do
      expect {
        post create_for_settings_api_keys_path("openai"), params: {
          api_credential: { api_key: "" }
        }
      }.not_to change { ApiCredential.unscoped.count }

      expect(response).to redirect_to(settings_api_keys_path)
      expect(flash[:alert]).to be_present
    end

    it "flash com status verified quando validação passa" do
      post create_for_settings_api_keys_path("openai"), params: {
        api_credential: { api_key: "sk-test-abc" }
      }
      follow_redirect!
      expect(response.body).to include(I18n.t("settings.api_keys.status.verified"))
    end
  end

  describe "PATCH /settings/api_keys/providers/:provider" do
    let!(:credential) do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, account: account, provider: "openai",
               encrypted_api_key: "sk-old-key")
      end
    end

    before do
      allow(ApiCredentials::ValidateService).to receive(:call) do |cred|
        cred.update!(last_validation_status: :verified, last_validated_at: Time.current)
        ApiCredentials::Result.success
      end
    end

    it "atualiza a credential existente" do
      patch update_for_settings_api_keys_path("openai"), params: {
        api_credential: { api_key: "sk-new-key" }
      }
      expect(credential.reload.encrypted_api_key).to eq("sk-new-key")
      expect(response).to redirect_to(settings_api_keys_path)
    end

    it "roda validação após update" do
      patch update_for_settings_api_keys_path("openai"), params: {
        api_credential: { api_key: "sk-new-key" }
      }
      expect(ApiCredentials::ValidateService).to have_received(:call)
    end

    it "retorna 404 quando credential não existe para o provider" do
      patch update_for_settings_api_keys_path("anthropic"), params: {
        api_credential: { api_key: "sk-ant-test" }
      }
      expect(response).to redirect_to(settings_api_keys_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /settings/api_keys/providers/:provider" do
    let!(:credential) do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, account: account, provider: "anthropic")
      end
    end

    it "destrói a credential" do
      expect {
        delete destroy_for_settings_api_keys_path("anthropic")
      }.to change { ApiCredential.unscoped.count }.by(-1)

      expect(response).to redirect_to(settings_api_keys_path)
      expect(flash[:notice]).to be_present
    end
  end

  describe "isolamento de tenant" do
    it "não afeta credentials de outra account" do
      other_cred = ActsAsTenant.with_tenant(other_account) do
        create(:api_credential, account: other_account, provider: "openai",
               encrypted_api_key: "sk-other-original")
      end

      allow(ApiCredentials::ValidateService).to receive(:call).and_return(ApiCredentials::Result.success)

      patch update_for_settings_api_keys_path("openai"), params: {
        api_credential: { api_key: "sk-hijacked" }
      }

      expect(other_cred.reload.encrypted_api_key).to eq("sk-other-original")
    end
  end
end
