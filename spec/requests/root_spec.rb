require "rails_helper"

RSpec.describe "Root", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe "GET /" do
    context "sem login" do
      it "retorna 200 e exibe a landing page" do
        get root_path
        expect(response).to have_http_status(:ok)
      end

      it "exibe headline principal" do
        get root_path
        expect(response.body).to include("Pare de inventar")
      end

      it "exibe preço do plano" do
        get root_path
        expect(response.body).to include("44,90")
      end

      it "não exibe referência exclusiva a mercado imobiliário no footer" do
        get root_path
        expect(response.body).not_to include("Mercado imobiliário brasileiro")
      end
    end

    context "com login" do
      before { sign_in user }

      it "renderiza o dashboard diretamente (authenticated root)" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
