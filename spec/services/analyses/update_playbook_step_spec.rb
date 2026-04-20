require "rails_helper"

RSpec.describe Analyses::UpdatePlaybookStep do
  let(:account) { create(:account) }
  let(:competitor) { create(:competitor, account: account) }

  let(:analysis) do
    ActsAsTenant.with_tenant(account) do
      create(:analysis, account: account, competitor: competitor,
        status: :completed,
        insights: {
          "reels" => { "summary" => "Reels com gancho emocional performam melhor." },
          "carousels" => { "summary" => "Carrosséis educativos geram mais saves." }
        },
        profile_metrics: { "posts_per_week" => 4.2, "avg_engagement_rate" => 0.042 }
      )
    end
  end

  let(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account, name: "Marketing Imobiliário", niche: "corretores") } }
  let(:analysis_playbook) { ActsAsTenant.with_tenant(account) { create(:analysis_playbook, analysis: analysis, playbook: playbook) } }

  let(:fake_llm_content) do
    "# Playbook — Marketing Imobiliário\n\n## Nicho e Contexto\nFoco em corretores brasileiros.\n\n---DIFF_SUMMARY---\nAdicionados insights de reels emocionais e carrosséis educativos."
  end

  let(:fake_llm_response) do
    instance_double(LLM::Response,
      content: fake_llm_content,
      provider: :anthropic,
      model: "claude-sonnet-4-6",
      usage: { prompt_tokens: 500, completion_tokens: 300 }
    )
  end

  before do
    ActsAsTenant.with_tenant(account) do
      create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test-key")
    end
    allow(LLM::Gateway).to receive(:complete).and_return(fake_llm_response)
    allow(LLM::UsageLogger).to receive(:log)
  end

  describe ".call" do
    it "cria nova PlaybookVersion" do
      ActsAsTenant.with_tenant(account) do
        expect {
          described_class.call(analysis_playbook)
        }.to change { PlaybookVersion.count }.by(1)
      end
    end

    it "incrementa current_version_number do playbook" do
      ActsAsTenant.with_tenant(account) do
        described_class.call(analysis_playbook)
        expect(playbook.reload.current_version_number).to eq(1)
      end
    end

    it "separa content e diff_summary corretamente" do
      ActsAsTenant.with_tenant(account) do
        described_class.call(analysis_playbook)
        version = PlaybookVersion.last
        expect(version.content).to include("# Playbook — Marketing Imobiliário")
        expect(version.content).not_to include("---DIFF_SUMMARY---")
        expect(version.diff_summary).to include("insights de reels emocionais")
      end
    end

    it "associa a versão com a análise que gerou" do
      ActsAsTenant.with_tenant(account) do
        described_class.call(analysis_playbook)
        version = PlaybookVersion.last
        expect(version.triggered_by_analysis_id).to eq(analysis.id)
      end
    end

    it "marca analysis_playbook como completed" do
      ActsAsTenant.with_tenant(account) do
        described_class.call(analysis_playbook)
        expect(analysis_playbook.reload.playbook_update_completed?).to be true
      end
    end

    it "retorna Result.success" do
      ActsAsTenant.with_tenant(account) do
        result = described_class.call(analysis_playbook)
        expect(result.success?).to be true
      end
    end

    it "chama LLM com anthropic provider" do
      ActsAsTenant.with_tenant(account) do
        described_class.call(analysis_playbook)
        expect(LLM::Gateway).to have_received(:complete).with(
          hash_including(provider: :anthropic, use_case: "update_playbook")
        )
      end
    end

    context "incorporação de feedbacks pendentes" do
      it "marca feedbacks como incorporated" do
        ActsAsTenant.with_tenant(account) do
          feedback = create(:playbook_feedback, account: account, playbook: playbook, status: :pending)
          described_class.call(analysis_playbook)
          expect(feedback.reload.status_incorporated?).to be true
        end
      end

      it "registra incorporated_in_version no feedback" do
        ActsAsTenant.with_tenant(account) do
          feedback = create(:playbook_feedback, account: account, playbook: playbook, status: :pending)
          described_class.call(analysis_playbook)
          expect(feedback.reload.incorporated_in_version_id).to be_present
        end
      end

      it "registra feedbacks_incorporated_count na versão" do
        ActsAsTenant.with_tenant(account) do
          create(:playbook_feedback, account: account, playbook: playbook, status: :pending)
          create(:playbook_feedback, account: account, playbook: playbook, status: :pending)
          described_class.call(analysis_playbook)
          version = PlaybookVersion.last
          expect(version.feedbacks_incorporated_count).to eq(2)
        end
      end

      it "não incorpora feedbacks dismissed" do
        ActsAsTenant.with_tenant(account) do
          dismissed = create(:playbook_feedback, account: account, playbook: playbook, status: :dismissed)
          described_class.call(analysis_playbook)
          expect(dismissed.reload.status_dismissed?).to be true
        end
      end
    end

    context "quando credential de generation não está configurada" do
      before do
        ActsAsTenant.with_tenant(account) do
          account.api_credentials.where(provider: "anthropic").destroy_all
        end
      end

      it "retorna Result.failure" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis_playbook)
          expect(result.success?).to be false
        end
      end

      it "marca analysis_playbook como failed" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis_playbook)
          expect(analysis_playbook.reload.playbook_update_failed?).to be true
        end
      end

      it "não levanta exceção" do
        ActsAsTenant.with_tenant(account) do
          expect { described_class.call(analysis_playbook) }.not_to raise_error
        end
      end
    end

    context "quando LLM levanta erro" do
      before do
        allow(LLM::Gateway).to receive(:complete).and_raise(LLM::Error.new("timeout"))
      end

      it "retorna Result.failure sem raise" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis_playbook)
          expect(result.success?).to be false
          expect { described_class.call(analysis_playbook) }.not_to raise_error
        end
      end

      it "marca analysis_playbook como failed" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis_playbook)
          expect(analysis_playbook.reload.playbook_update_failed?).to be true
        end
      end
    end

    context "quando LLM responde sem separador ---DIFF_SUMMARY---" do
      before do
        no_separator_response = instance_double(LLM::Response,
          content: "# Playbook — Marketing\n\nConteúdo sem separador.",
          provider: :anthropic,
          model: "claude-sonnet-4-6",
          usage: { prompt_tokens: 200, completion_tokens: 150 }
        )
        allow(LLM::Gateway).to receive(:complete).and_return(no_separator_response)
      end

      it "usa todo o conteúdo e diff_summary genérico" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis_playbook)
          version = PlaybookVersion.last
          expect(version.content).to include("# Playbook — Marketing")
          expect(version.diff_summary).to be_present
        end
      end
    end
  end
end
