require "rails_helper"

RSpec.describe "PlaybookSuggestions", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:playbook) do
    ActsAsTenant.with_tenant(account) { create(:playbook, :with_version, account: account) }
  end

  before { sign_in user }

  describe "POST /playbooks/:playbook_id/playbook_suggestions" do
    let(:llm_response) do
      instance_double(LLM::Response,
        content: JSON.generate({
          "suggestions" => [{
            "hook" => "Gancho teste",
            "caption_draft" => "Caption teste",
            "format_details" => {},
            "suggested_hashtags" => ["imoveis"],
            "rationale" => "Funciona porque..."
          }]
        })
      )
    end

    before do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test")
      end
      allow(LLM::Gateway).to receive(:complete).and_return(llm_response)
    end

    it "cria sugestões e retorna turbo_stream" do
      post playbook_playbook_suggestions_path(playbook),
           params: { content_type: "reel", quantity: 1 },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      ActsAsTenant.with_tenant(account) do
        expect(PlaybookSuggestion.count).to eq(1)
      end
    end
  end

  describe "PATCH /playbooks/:playbook_id/playbook_suggestions/:id" do
    let(:suggestion) do
      ActsAsTenant.with_tenant(account) do
        create(:playbook_suggestion, account: account, playbook: playbook, status: :draft)
      end
    end

    it "atualiza status para saved e retorna turbo_stream" do
      patch playbook_playbook_suggestion_path(playbook, suggestion),
            params: { status: "saved" },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(suggestion.reload.status).to eq("saved")
    end

    it "atualiza status para discarded" do
      patch playbook_playbook_suggestion_path(playbook, suggestion),
            params: { status: "discarded" },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(suggestion.reload.status).to eq("discarded")
    end
  end
end
