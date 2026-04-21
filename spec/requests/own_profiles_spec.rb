require "rails_helper"

RSpec.describe "OwnProfiles", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before { sign_in user }

  describe "GET /own_profiles" do
    it "retorna 200" do
      get own_profiles_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /own_profiles/new" do
    it "retorna 200" do
      get new_own_profile_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /own_profiles" do
    context "com params válidos" do
      it "cria perfil e redireciona para show" do
        post own_profiles_path, params: { own_profile: { instagram_handle: "meuperfil" } }
        profile = ActsAsTenant.with_tenant(account) { OwnProfile.last }
        expect(response).to redirect_to(own_profile_path(profile))
      end
    end

    context "com params inválidos" do
      it "retorna 422 com formulário" do
        post own_profiles_path, params: { own_profile: { instagram_handle: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /own_profiles/:id" do
    it "retorna 200" do
      profile = ActsAsTenant.with_tenant(account) { create(:own_profile, account: account) }
      get own_profile_path(profile)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /own_profiles/:id/edit" do
    it "retorna 200" do
      profile = ActsAsTenant.with_tenant(account) { create(:own_profile, account: account) }
      get edit_own_profile_path(profile)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /own_profiles/:id" do
    it "atualiza e redireciona para show" do
      profile = ActsAsTenant.with_tenant(account) { create(:own_profile, account: account) }
      patch own_profile_path(profile), params: { own_profile: { full_name: "Novo Nome" } }
      expect(response).to redirect_to(own_profile_path(profile))
    end
  end

  describe "DELETE /own_profiles/:id" do
    it "remove e redireciona para index" do
      profile = ActsAsTenant.with_tenant(account) { create(:own_profile, account: account) }
      delete own_profile_path(profile)
      expect(response).to redirect_to(own_profiles_path)
    end
  end

  describe "POST /own_profiles/:id/sync" do
    context "com token válido" do
      it "executa sync e redireciona com notice" do
        profile = ActsAsTenant.with_tenant(account) { create(:own_profile, :with_token, account: account) }
        result = instance_double(OwnProfiles::Result, success?: true, data: { synced: 5 })
        allow(OwnProfiles::SyncPostsService).to receive(:new).and_return(
          instance_double(OwnProfiles::SyncPostsService, call: result)
        )

        post sync_own_profile_path(profile)
        expect(response).to redirect_to(own_profile_path(profile))
        expect(flash[:notice]).to include("5 post(s)")
      end
    end

    context "com token expirado" do
      it "redireciona para edit com alert" do
        profile = ActsAsTenant.with_tenant(account) { create(:own_profile, :with_expired_token, account: account) }

        post sync_own_profile_path(profile)
        expect(response).to redirect_to(edit_own_profile_path(profile))
        expect(flash[:alert]).to include("Token Meta")
      end
    end
  end

  describe "sem autenticação" do
    before { sign_out user }

    it "redireciona para login" do
      get own_profiles_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
