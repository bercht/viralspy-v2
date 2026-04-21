require "rails_helper"

RSpec.describe "Settings::MediaGeneration", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:user_info_url) { "https://api.heygen.com/v2/voices" }

  before { sign_in user }

  describe "GET /settings/media_generation" do
    it "retorna 200" do
      get settings_media_generation_path
      expect(response).to have_http_status(:ok)
    end

    it "não requer chave configurada" do
      get settings_media_generation_path
      expect(response.body).to include("API Key HeyGen")
    end
  end

  describe "PATCH /settings/media_generation" do
    context "com api_key nova" do
      it "cria ApiCredential com provider heygen" do
        expect {
          patch settings_media_generation_path, params: { settings: { api_key: "new_heygen_key" } }
        }.to change { ActsAsTenant.with_tenant(account) { account.api_credentials.where(provider: "heygen").count } }.by(1)
      end

      it "redireciona com notice" do
        patch settings_media_generation_path, params: { settings: { api_key: "key" } }
        expect(response).to redirect_to(settings_media_generation_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "com avatar_id e voice_id" do
      it "atualiza media_generation_preferences do account" do
        patch settings_media_generation_path, params: {
          settings: { avatar_id: "my_avatar", voice_id: "my_voice" }
        }
        account.reload
        expect(account.media_generation_preferences["avatar_id"]).to eq("my_avatar")
        expect(account.media_generation_preferences["voice_id"]).to eq("my_voice")
      end
    end

    context "com custom_voice_ids" do
      it "normaliza e persiste lista de IDs customizados" do
        patch settings_media_generation_path, params: {
          settings: { custom_voice_ids: "voice_a\nvoice_b, voice_a,  " }
        }

        account.reload
        expect(account.media_generation_preferences["custom_voice_ids"]).to eq([ "voice_a", "voice_b" ])
      end
    end
  end

  describe "POST /settings/media_generation/validate_key" do
    context "sem credential configurada" do
      it "retorna valid: false" do
        post validate_key_settings_media_generation_path
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
      end
    end

    context "com credential configurada e chave válida" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "heygen",
                 encrypted_api_key: "test_key", active: true)
        end
        stub_request(:get, user_info_url).to_return(status: 200, body: {}.to_json)
      end

      it "retorna valid: true" do
        post validate_key_settings_media_generation_path
        json = JSON.parse(response.body)
        expect(json["valid"]).to be true
      end
    end

    context "com credential configurada mas chave inválida" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "heygen",
                 encrypted_api_key: "bad_key", active: true)
        end
        stub_request(:get, user_info_url).to_return(status: 401, body: {}.to_json)
      end

      it "retorna valid: false" do
        post validate_key_settings_media_generation_path
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
      end
    end
  end

  context "sem autenticação" do
    before { sign_out user }

    it "redireciona para login" do
      get settings_media_generation_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /settings/media_generation/avatars" do
    let(:avatars_url) { "https://api.heygen.com/v3/avatars/looks" }

    context "sem credential configurada" do
      it "retorna JSON com erro e status 422" do
        get avatars_settings_media_generation_path
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "com credential configurada" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "heygen",
                 encrypted_api_key: "test_key", active: true)
        end
        stub_request(:get, avatars_url)
          .to_return(
            status: 200,
            body: { data: { list: [
              { "id" => "a1", "name" => "Avatar 1", "preview_image_url" => "https://example.com/a1.jpg" }
            ] } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retorna JSON com avatares e status 200" do
        get avatars_settings_media_generation_path
        json = JSON.parse(response.body)
        expect(json["avatars"]).to be_an(Array)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /settings/media_generation/voices" do
    let(:voices_url) { "https://api.heygen.com/v3/voices" }
    let(:custom_voice_id) { "kooxE9YPGSSgFoWEWN44" }
    let(:custom_voice_url) { "https://api.heygen.com/v2/voices/#{custom_voice_id}" }

    context "sem credential configurada" do
      it "retorna JSON com erro e status 422" do
        get voices_settings_media_generation_path
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "com credential configurada" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "heygen",
                 encrypted_api_key: "test_key", active: true)
        end
        stub_request(:get, voices_url)
          .with(query: { "limit" => "100" })
          .to_return(
            status: 200,
            body: { data: [
              { "voice_id" => "v1", "name" => "Voz 1", "language" => "pt-BR" }
            ] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retorna JSON com vozes e status 200" do
        get voices_settings_media_generation_path
        json = JSON.parse(response.body)
        expect(json["voices"]).to be_an(Array)
        expect(response).to have_http_status(:ok)
      end
    end

    context "com custom voices configuradas" do
      before do
        ActsAsTenant.with_tenant(account) do
          account.update!(media_generation_preferences: { "custom_voice_ids" => [ custom_voice_id ] })
          create(:api_credential, account: account, provider: "heygen",
                 encrypted_api_key: "test_key", active: true)
        end
        stub_request(:get, custom_voice_url)
          .to_return(
            status: 200,
            body: {
              error: nil,
              data: { voice_id: custom_voice_id, name: "Curt Voice Clone", language: "Portuguese" }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        stub_request(:get, voices_url)
          .with(query: { "limit" => "100" })
          .to_return(
            status: 200,
            body: { data: [
              { "voice_id" => "v1", "name" => "Voz 1", "language" => "pt-BR" }
            ] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "inclui custom voices no topo quando configuradas" do
        get voices_settings_media_generation_path
        json = JSON.parse(response.body)

        expect(json["voices"].map { |voice| voice["id"] }).to eq([ custom_voice_id, "v1" ])
        expect(json["voices"].first["name"]).to eq("Curt Voice Clone ★")
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
