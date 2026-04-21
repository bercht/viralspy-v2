require "rails_helper"

RSpec.describe Playbooks::GenerateSuggestionsService do
  let(:account) { create(:account) }
  let(:playbook_with_version) do
    ActsAsTenant.with_tenant(account) { create(:playbook, :with_version, account: account) }
  end
  let(:playbook_without_version) do
    ActsAsTenant.with_tenant(account) { create(:playbook, account: account) }
  end

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

  describe ".call" do
    context "playbook sem versão" do
      it "retorna failure com error_code :no_content" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(
            playbook: playbook_without_version,
            content_type: "reel",
            quantity: 1
          )
          expect(result).to be_failure
          expect(result.error_code).to eq(:no_content)
        end
      end
    end

    context "sem credential configurada" do
      it "retorna failure com error_code :no_credential" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(
            playbook: playbook_with_version,
            content_type: "reel",
            quantity: 1
          )
          expect(result).to be_failure
          expect(result.error_code).to eq(:no_credential)
        end
      end
    end

    context "com credential e LLM retornando JSON válido" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test")
        end
        allow(LLM::Gateway).to receive(:complete).and_return(llm_response)
      end

      it "retorna success com sugestões" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(
            playbook: playbook_with_version,
            content_type: "reel",
            quantity: 1
          )
          expect(result).to be_success
          expect(result.data[:suggestions]).not_to be_empty
        end
      end

      it "persiste PlaybookSuggestion no banco" do
        ActsAsTenant.with_tenant(account) do
          expect {
            described_class.call(
              playbook: playbook_with_version,
              content_type: "reel",
              quantity: 1
            )
          }.to change(PlaybookSuggestion, :count).by(1)
        end
      end

      it "chama LLM com use_case playbook_suggestions" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(
            playbook: playbook_with_version,
            content_type: "reel",
            quantity: 1
          )
          expect(LLM::Gateway).to have_received(:complete).with(
            hash_including(use_case: "playbook_suggestions", json_mode: true)
          )
        end
      end
    end

    context "LLM retorna JSON inválido" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test")
        end
        invalid_response = instance_double(LLM::Response, content: "não é JSON")
        allow(LLM::Gateway).to receive(:complete).and_return(invalid_response)
      end

      it "retorna success com suggestions vazias (parse interno silencioso)" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(
            playbook: playbook_with_version,
            content_type: "reel",
            quantity: 1
          )
          # parse_suggestions captura JSON::ParserError internamente e retorna []
          # o service retorna success com suggestions vazio
          expect(result).to be_success
          expect(result.data[:suggestions]).to be_empty
        end
      end
    end
  end
end
