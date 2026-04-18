require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe "GET /dashboard" do
    context "sem login" do
      it "redireciona para sign_in" do
        get dashboard_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "com login" do
      before { sign_in user }

      it "retorna 200" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
      end

      it "inclui o nome do usuário no body" do
        get dashboard_path
        expect(response.body).to include(user.first_name)
      end

      it "inclui o nome da account no body" do
        get dashboard_path
        expect(response.body).to include(account.name)
      end
    end
  end
end
