# spec/requests/design_system_spec.rb
require "rails_helper"

RSpec.describe "DesignSystem", type: :request do
  describe "GET /design-system" do
    context "in development/test environment" do
      it "renders the reference page" do
        get "/design-system"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Design System — ViralSpy")
      end

      it "does not require authentication" do
        get "/design-system"
        expect(response).not_to redirect_to(new_user_session_path)
      end
    end
  end
end
