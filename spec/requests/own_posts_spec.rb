require "rails_helper"

RSpec.describe "OwnPosts", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:profile) do
    ActsAsTenant.with_tenant(account) { create(:own_profile, account: account) }
  end
  let(:own_post) do
    ActsAsTenant.with_tenant(account) { create(:own_post, account: account, own_profile: profile) }
  end

  before { sign_in user }

  describe "GET /own_profiles/:own_profile_id/own_posts" do
    it "retorna 200" do
      get own_profile_own_posts_path(profile)
      expect(response).to have_http_status(:ok)
    end

    it "filtra por tipo quando type param presente" do
      get own_profile_own_posts_path(profile), params: { type: "reel" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /own_profiles/:own_profile_id/own_posts/:id" do
    it "retorna 200" do
      get own_profile_own_post_path(profile, own_post)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /own_profiles/:own_profile_id/own_posts/:id" do
    it "salva performance_rating e redireciona" do
      patch own_profile_own_post_path(profile, own_post),
        params: { own_post: { performance_rating: "good" } }
      expect(response).to redirect_to(own_profile_own_post_path(profile, own_post))
      expect(flash[:notice]).to eq("Avaliação salva.")
    end
  end

  describe "sem autenticação" do
    before { sign_out user }

    it "redireciona para login" do
      get own_profile_own_posts_path(profile)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
