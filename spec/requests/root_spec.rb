require 'rails_helper'

RSpec.describe "Root", type: :request do
  describe "GET /" do
    context "sem login" do
      it "redireciona para /dashboard que redireciona para sign_in" do
        get root_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
