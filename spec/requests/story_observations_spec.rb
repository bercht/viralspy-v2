require "rails_helper"

RSpec.describe "StoryObservations", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) do
    ActsAsTenant.with_tenant(account) { create(:competitor, account: account) }
  end

  before { sign_in user }

  describe "GET /competitors/:competitor_id/story_observations" do
    it "retorna 200" do
      get competitor_story_observations_path(competitor)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /competitors/:competitor_id/story_observations/new" do
    it "retorna 200" do
      get new_competitor_story_observation_path(competitor)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /competitors/:competitor_id/story_observations" do
    context "com params válidos" do
      it "cria observação e redireciona para index" do
        post competitor_story_observations_path(competitor),
          params: { story_observation: { observed_on: Date.today, format: "video", perceived_engagement: "high" } }
        expect(response).to redirect_to(competitor_story_observations_path(competitor))
        expect(flash[:notice]).to eq("Observação registrada.")
      end
    end

    context "com params inválidos (sem observed_on)" do
      it "retorna 422" do
        post competitor_story_observations_path(competitor),
          params: { story_observation: { observed_on: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /competitors/:competitor_id/story_observations/:id" do
    it "remove e redireciona para index" do
      observation = ActsAsTenant.with_tenant(account) do
        create(:story_observation, account: account, competitor: competitor)
      end
      delete competitor_story_observation_path(competitor, observation)
      expect(response).to redirect_to(competitor_story_observations_path(competitor))
      expect(flash[:notice]).to eq("Observação removida.")
    end
  end

  describe "sem autenticação" do
    before { sign_out user }

    it "redireciona para login" do
      get competitor_story_observations_path(competitor)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
