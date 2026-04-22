# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ContentSuggestions::Generate", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }
  let(:analysis) do
    ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) }
  end
  let(:playbook) do
    ActsAsTenant.with_tenant(account) { create(:playbook, :with_version, account: account) }
  end

  before { sign_in user }

  def post_generate(content_type: "reel", quantity: 2)
    post content_suggestions_generate_index_path(
      competitor_id: competitor.id,
      analysis_id: analysis.id
    ), params: { content_type: content_type, quantity: quantity },
       headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  describe "POST /content_suggestions/generate" do
    let(:llm_response) do
      instance_double(LLM::Response,
        content: JSON.generate({
          "suggestions" => [
            {
              "hook" => "Gancho teste",
              "caption_draft" => "Caption teste",
              "format_details" => {},
              "suggested_hashtags" => ["teste"],
              "rationale" => "Funciona porque..."
            }
          ]
        })
      )
    end

    before do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test")
        create(:analysis_playbook, analysis: analysis, playbook: playbook)
      end
      allow(LLM::Gateway).to receive(:complete).and_return(llm_response)
    end

    context "com params válidos" do
      it "retorna turbo_stream" do
        post_generate

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "persiste PlaybookSuggestion" do
        expect { post_generate }.to change {
          ActsAsTenant.with_tenant(account) { PlaybookSuggestion.count }
        }.by(1)
      end
    end

    context "com content_type inválido" do
      it "redireciona" do
        post_generate(content_type: "invalido")
        expect(response).to be_redirect
      end
    end

    context "sem playbook configurado" do
      before do
        ActsAsTenant.with_tenant(account) do
          analysis.analysis_playbooks.destroy_all
          account.playbooks.destroy_all
        end
      end

      it "redireciona com alert" do
        post_generate
        expect(response).to be_redirect
      end
    end

    context "sem autenticação" do
      before { sign_out user }

      it "redireciona para login" do
        post_generate
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
