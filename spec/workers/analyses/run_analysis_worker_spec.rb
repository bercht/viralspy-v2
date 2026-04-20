require "rails_helper"

RSpec.describe Analyses::RunAnalysisWorker do
  let(:account) { create(:account) }
  let(:competitor) { create(:competitor, account: account) }
  let(:analysis) { create(:analysis, account: account, competitor: competitor, status: :pending) }

  def stub_step(klass, outcome: :success)
    if outcome == :success
      allow(klass).to receive(:call).and_return(Analyses::Result.success)
    else
      allow(klass).to receive(:call) do
        analysis.update!(status: :failed, error_message: "#{klass.name} failed", finished_at: Time.current)
        Analyses::Result.failure(error: "#{klass.name} failed", error_code: :test_failure)
      end
    end
  end

  def stub_all_steps_success
    stub_step(Analyses::ScrapeStep)
    stub_step(Analyses::ProfileMetricsStep)
    stub_step(Analyses::ScoreAndSelectStep)
    stub_step(Analyses::TranscribeStep)
    stub_step(Analyses::AnalyzeStep)
    allow(Analyses::GenerateSuggestionsStep).to receive(:call) do
      analysis.update!(status: :completed, finished_at: Time.current)
      Analyses::Result.success
    end
  end

  describe "#perform" do
    context "happy path — all steps succeed" do
      before { stub_all_steps_success }

      it "calls all 6 steps in order" do
        described_class.new.perform(analysis.id)

        [Analyses::ScrapeStep, Analyses::ProfileMetricsStep, Analyses::ScoreAndSelectStep,
         Analyses::TranscribeStep, Analyses::AnalyzeStep, Analyses::GenerateSuggestionsStep].each do |step|
          expect(step).to have_received(:call)
        end
      end

      it "results in a completed analysis" do
        described_class.new.perform(analysis.id)
        expect(analysis.reload.status).to eq("completed")
      end
    end

    context "ScrapeStep fails" do
      before do
        stub_step(Analyses::ScrapeStep, outcome: :failure)
        stub_step(Analyses::ProfileMetricsStep)
        stub_step(Analyses::ScoreAndSelectStep)
        stub_step(Analyses::TranscribeStep)
        stub_step(Analyses::AnalyzeStep)
        stub_step(Analyses::GenerateSuggestionsStep)
      end

      it "stops pipeline after ScrapeStep and does not call subsequent steps" do
        described_class.new.perform(analysis.id)

        expect(Analyses::ScrapeStep).to have_received(:call)
        expect(Analyses::ProfileMetricsStep).not_to have_received(:call)
        expect(analysis.reload.status).to eq("failed")
      end
    end

    context "TranscribeStep fails" do
      before do
        stub_step(Analyses::ScrapeStep)
        stub_step(Analyses::ProfileMetricsStep)
        stub_step(Analyses::ScoreAndSelectStep)
        stub_step(Analyses::TranscribeStep, outcome: :failure)
        stub_step(Analyses::AnalyzeStep)
        stub_step(Analyses::GenerateSuggestionsStep)
      end

      it "stops pipeline after TranscribeStep" do
        described_class.new.perform(analysis.id)

        expect(Analyses::TranscribeStep).to have_received(:call)
        expect(Analyses::AnalyzeStep).not_to have_received(:call)
        expect(analysis.reload.status).to eq("failed")
      end
    end

    context "GenerateSuggestionsStep fails" do
      before do
        stub_step(Analyses::ScrapeStep)
        stub_step(Analyses::ProfileMetricsStep)
        stub_step(Analyses::ScoreAndSelectStep)
        stub_step(Analyses::TranscribeStep)
        stub_step(Analyses::AnalyzeStep)
        stub_step(Analyses::GenerateSuggestionsStep, outcome: :failure)
      end

      it "marks analysis as failed" do
        described_class.new.perform(analysis.id)
        expect(analysis.reload.status).to eq("failed")
      end
    end

    context "analysis not found" do
      it "returns gracefully without raising" do
        expect { described_class.new.perform(999_999) }.not_to raise_error
      end
    end

    context "unexpected exception inside pipeline" do
      before do
        allow(Analyses::ScrapeStep).to receive(:call).and_raise(RuntimeError, "unexpected crash")
      end

      it "marks analysis as failed with finished_at" do
        described_class.new.perform(analysis.id)

        reloaded = analysis.reload
        expect(reloaded.status).to eq("failed")
        expect(reloaded.error_message).to include("unexpected crash")
        expect(reloaded.finished_at).to be_present
      end

      it "does not re-raise the exception" do
        expect { described_class.new.perform(analysis.id) }.not_to raise_error
      end

      it "still sets started_at before the crash" do
        described_class.new.perform(analysis.id)
        expect(analysis.reload.started_at).to be_present
      end
    end

    context "started_at lifecycle" do
      before { stub_all_steps_success }

      it "sets started_at before any step runs" do
        started_at_during_step = nil

        allow(Analyses::ScrapeStep).to receive(:call) do |_analysis|
          started_at_during_step = analysis.reload.started_at
          Analyses::Result.success
        end

        described_class.new.perform(analysis.id)
        expect(started_at_during_step).to be_present
      end

      it "does not reset started_at if already set (idempotence)" do
        original = 5.minutes.ago
        analysis.update!(started_at: original)

        described_class.new.perform(analysis.id)
        expect(analysis.reload.started_at).to be_within(1.second).of(original)
      end
    end

    context "tenant isolation" do
      before { stub_all_steps_success }

      it "runs steps within the correct tenant" do
        expect(ActsAsTenant).to receive(:with_tenant).with(account).and_call_original

        described_class.new.perform(analysis.id)
      end
    end
  end
end
