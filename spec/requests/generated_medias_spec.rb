require "rails_helper"

RSpec.describe "GeneratedMedias", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:suggestion) do
    ActsAsTenant.with_tenant(account) { create(:content_suggestion, account: account) }
  end
  let(:generate_url) { "https://api.heygen.com/v2/video/generate" }

  before do
    sign_in user
    account.update!(media_generation_preferences: {
      "avatar_id" => "avatar_123",
      "voice_id" => "voice_pt_br"
    })
    ActsAsTenant.with_tenant(account) do
      create(:api_credential, account: account, provider: "heygen",
             encrypted_api_key: "test_key", active: true)
    end
    allow(MediaGeneration::PollWorker).to receive(:perform_in)
  end

  describe "POST /content_suggestions/:id/generated_medias" do
    context "autenticado, com configuração completa" do
      before do
        stub_request(:post, generate_url)
          .to_return(
            status: 202,
            body: { code: 100, data: { video_id: "job_new" }, message: "success" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "cria GeneratedMedia" do
        expect {
          post content_suggestion_generated_medias_path(suggestion),
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change { GeneratedMedia.unscoped.count }.by(1)
      end

      it "retorna Turbo Stream" do
        post content_suggestion_generated_medias_path(suggestion),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(response).to have_http_status(:ok)
      end
    end

    context "sem autenticação" do
      before { sign_out user }

      it "redireciona para login" do
        post content_suggestion_generated_medias_path(suggestion)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "com suggestion de outro tenant" do
      let(:other_account) { create(:account) }
      let(:other_suggestion) do
        ActsAsTenant.with_tenant(other_account) { create(:content_suggestion, account: other_account) }
      end

      it "retorna 404" do
        post content_suggestion_generated_medias_path(other_suggestion)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
