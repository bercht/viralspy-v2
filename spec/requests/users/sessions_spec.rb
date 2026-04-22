require "rails_helper"

RSpec.describe "Users::Sessions", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe "GET /users/sign_in" do
    it "retorna 200" do
      get new_user_session_path
      expect(response).to have_http_status(:ok)
    end

    it "exibe headline do painel esquerdo" do
      get new_user_session_path
      expect(response.body).to include("Bem-vindo")
    end

    it "exibe campo de e-mail" do
      get new_user_session_path
      expect(response.body).to include("E-mail")
    end
  end

  describe "POST /users/sign_in com credenciais inválidas" do
    it "exibe mensagem de erro" do
      post user_session_path, params: {
        user: { email: "wrong@test.com", password: "wrong" }
      }
      expect(response.body).to include("nválid")
    end
  end
end
