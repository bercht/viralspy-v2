require "rails_helper"

RSpec.describe Analyses::RunAnalysisWorker, "com playbooks selecionados" do
  let(:account) { create(:account) }
  let(:competitor) { create(:competitor, account: account) }

  let(:analysis) do
    ActsAsTenant.with_tenant(account) do
      create(:analysis, :completed, account: account, competitor: competitor)
    end
  end

  let(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

  before do
    # Stub all pipeline steps to succeed instantly
    stub_step(Analyses::ScrapeStep)
    stub_step(Analyses::ProfileMetricsStep)
    stub_step(Analyses::ScoreAndSelectStep)
    stub_step(Analyses::TranscribeStep)
    stub_step(Analyses::AnalyzeStep)
    stub_step(Analyses::GenerateSuggestionsStep) do
      ActsAsTenant.without_tenant { Analysis.find(analysis.id) }.tap do |a|
        a.update_columns(status: 7, finished_at: Time.current)
      end
    end
  end

  def stub_step(step_class, &block)
    allow(step_class).to receive(:call) do |arg|
      block.call if block
      Analyses::Result.success
    end
  end

  describe "#perform" do
    context "quando há analysis_playbooks selecionados" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:analysis_playbook, analysis: analysis, playbook: playbook)
        end
        allow(Analyses::UpdatePlaybookStep).to receive(:call).and_return(Analyses::Result.success)
      end

      it "chama UpdatePlaybookStep para cada analysis_playbook" do
        described_class.new.perform(analysis.id)
        expect(Analyses::UpdatePlaybookStep).to have_received(:call).once
      end

      it "chama UpdatePlaybookStep com o analysis_playbook correto" do
        ap = ActsAsTenant.with_tenant(account) { analysis.analysis_playbooks.first }
        described_class.new.perform(analysis.id)
        expect(Analyses::UpdatePlaybookStep).to have_received(:call).with(ap)
      end
    end

    context "quando UpdatePlaybookStep falha para um playbook" do
      let(:playbook2) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

      before do
        ActsAsTenant.with_tenant(account) do
          create(:analysis_playbook, analysis: analysis, playbook: playbook)
          create(:analysis_playbook, analysis: analysis, playbook: playbook2)
        end

        call_count = 0
        allow(Analyses::UpdatePlaybookStep).to receive(:call) do
          call_count += 1
          raise "erro simulado" if call_count == 1
          Analyses::Result.success
        end
      end

      it "não levanta exceção" do
        expect { described_class.new.perform(analysis.id) }.not_to raise_error
      end

      it "ainda chama UpdatePlaybookStep para os outros playbooks" do
        described_class.new.perform(analysis.id)
        expect(Analyses::UpdatePlaybookStep).to have_received(:call).twice
      end
    end

    context "quando análise não tem playbooks selecionados" do
      before do
        allow(Analyses::UpdatePlaybookStep).to receive(:call)
      end

      it "não chama UpdatePlaybookStep" do
        described_class.new.perform(analysis.id)
        expect(Analyses::UpdatePlaybookStep).not_to have_received(:call)
      end

      it "completa normalmente" do
        expect { described_class.new.perform(analysis.id) }.not_to raise_error
      end
    end
  end
end
