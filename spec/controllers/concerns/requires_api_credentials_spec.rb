require "rails_helper"

RSpec.describe RequiresApiCredentials, type: :controller do
  controller(ApplicationController) do
    include RequiresApiCredentials

    before_action :require_api_credentials_configured!

    def index
      render plain: "ok"
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }
  end

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before do
    sign_in(user)
    ActsAsTenant.current_tenant = account
  end

  context "when account is ready for analysis" do
    before do
      allow_any_instance_of(Account).to receive(:ready_for_analysis?).and_return(true)
    end

    it "allows the request through" do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("ok")
    end
  end

  context "when account is missing credentials" do
    before do
      allow_any_instance_of(Account).to receive(:ready_for_analysis?).and_return(false)
      allow_any_instance_of(Account)
        .to receive(:missing_credentials_for_analysis)
        .and_return([ :openai, :assemblyai ])
    end

    it "redirects to settings llm preferences page" do
      get :index
      expect(response).to redirect_to(edit_settings_llm_preferences_path)
    end

    it "sets an alert flash listing missing providers with use cases" do
      get :index
      expect(flash[:alert]).to include("OpenAI")
      expect(flash[:alert]).to include("AssemblyAI")
      expect(flash[:alert]).to include("análise estruturada")
      expect(flash[:alert]).to include("transcrição")
      expect(flash[:alert]).to include("Configurações → Preferências de Provider")
    end

    it "does not include providers that are configured" do
      get :index
      expect(flash[:alert]).not_to include("Anthropic")
    end
  end

  context "when current_tenant is nil" do
    before do
      ActsAsTenant.current_tenant = nil
      allow(controller).to receive(:current_tenant).and_return(nil)
    end

    it "allows the request through (no-op)" do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end
end
