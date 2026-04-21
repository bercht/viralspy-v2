require "rails_helper"

# skip_tenant: true — allows the controller's set_current_tenant to apply
# full acts_as_tenant scoping during requests (without_tenant would bypass it)
RSpec.describe "Competitors", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:other_account) { create(:account) }

  before { sign_in user }

  describe "GET /competitors" do
    it "retorna 200" do
      get competitors_path
      expect(response).to have_http_status(:ok)
    end

    it "lista competitors do tenant" do
      competitor = ActsAsTenant.with_tenant(account) { create(:competitor, account: account) }
      get competitors_path
      expect(response.body).to include("@#{competitor.instagram_handle}")
    end

    it "não lista competitors de outra account" do
      other = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
      get competitors_path
      expect(response.body).not_to include("@#{other.instagram_handle}")
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        get competitors_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /competitors/new" do
    it "retorna 200" do
      get new_competitor_path
      expect(response).to have_http_status(:ok)
    end

    it "renderiza datalist com nichos únicos e ordenados do tenant atual" do
      ActsAsTenant.with_tenant(account) do
        create(:competitor, account: account, instagram_handle: "comp_a", niche: "Nutrição funcional")
        create(:competitor, account: account, instagram_handle: "comp_b", niche: "Marketing imobiliário")
        create(:competitor, account: account, instagram_handle: "comp_c", niche: "Marketing imobiliário")
        create(:competitor, account: account, instagram_handle: "comp_d", niche: nil)
        create(:competitor, account: account, instagram_handle: "comp_e", niche: "")
      end
      ActsAsTenant.with_tenant(other_account) do
        create(:competitor, account: other_account, instagram_handle: "comp_outro", niche: "Nicho externo")
      end

      get new_competitor_path

      doc = Nokogiri::HTML(response.body)
      input = doc.at_css("input#competitor_niche")
      datalist = doc.at_css("datalist#niche_suggestions")
      values = datalist.css("option").map { |option| option["value"] }

      expect(input["list"]).to eq("niche_suggestions")
      expect(values).to eq([ "Marketing imobiliário", "Nutrição funcional" ])
    end
  end

  describe "POST /competitors" do
    context "com dados válidos" do
      it "cria o competitor e redireciona para show" do
        expect {
          post competitors_path, params: { competitor: { instagram_handle: "imobtest" } }
        }.to change { Competitor.unscoped.count }.by(1)

        expect(response).to redirect_to(competitor_path(Competitor.unscoped.last))
      end

      it "normaliza handle com @ para sem @" do
        post competitors_path, params: { competitor: { instagram_handle: "@imobtest" } }
        expect(Competitor.unscoped.last.instagram_handle).to eq("imobtest")
      end
    end

    context "com dados inválidos" do
      it "re-renderiza new com status unprocessable_content" do
        post competitors_path, params: { competitor: { instagram_handle: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /competitors/:id" do
    let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }

    it "retorna 200" do
      get competitor_path(competitor)
      expect(response).to have_http_status(:ok)
    end

    it "retorna 404 para competitor de outra account" do
      other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
      get competitor_path(other_competitor)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /competitors/:id/edit" do
    let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }

    it "retorna 200" do
      get edit_competitor_path(competitor)
      expect(response).to have_http_status(:ok)
    end

    it "retorna 404 para competitor de outra account" do
      other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
      get edit_competitor_path(other_competitor)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /competitors/:id" do
    let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account, niche: "Antigo") } }

    it "atualiza e redireciona para show" do
      patch competitor_path(competitor), params: { competitor: { niche: "Novo nicho" } }

      expect(response).to redirect_to(competitor_path(competitor))
      expect(competitor.reload.niche).to eq("Novo nicho")
    end

    it "retorna 404 para competitor de outra account" do
      other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
      patch competitor_path(other_competitor), params: { competitor: { niche: "Novo nicho" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /competitors/:id" do
    let!(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }

    it "destrói e redireciona para index" do
      expect {
        delete competitor_path(competitor)
      }.to change { Competitor.unscoped.count }.by(-1)

      expect(response).to redirect_to(competitors_path)
    end

    it "retorna 404 para competitor de outra account" do
      other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
      delete competitor_path(other_competitor)
      expect(response).to have_http_status(:not_found)
    end
  end
end
