require "rails_helper"

RSpec.describe "Root", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe "GET /" do
    context "sem login" do
      it "redireciona para sign_in" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
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
