module Analyses
  class RunAnalysisWorker
    include Sidekiq::Worker

    # retry: 0 — pipeline custa ~R$0,35. Falha = usuário reroda criando nova Analysis.
    sidekiq_options queue: "analyses", retry: 0

    STEPS = [
      Analyses::ScrapeStep,
      Analyses::ProfileMetricsStep,
      Analyses::ScoreAndSelectStep,
      Analyses::TranscribeStep,
      Analyses::AnalyzeStep,
      Analyses::GenerateSuggestionsStep
    ].freeze

    def perform(analysis_id)
      analysis = Analysis.find(analysis_id)

      ActsAsTenant.with_tenant(analysis.account) do
        run_pipeline(analysis)
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("[Analyses::RunAnalysisWorker] Analysis #{analysis_id} not found")
    end

    private

    def run_pipeline(analysis)
      Rails.logger.info("[Analysis##{analysis.id}] Pipeline starting")

      STEPS.each do |step_class|
        step_name = step_class.name.demodulize
        Rails.logger.info("[Analysis##{analysis.id}] → #{step_name}")

        result = step_class.call(analysis)

        if result.failure?
          Rails.logger.error(
            "[Analysis##{analysis.id}] Pipeline aborted at #{step_name}: #{result.error_code} - #{result.error}"
          )
          return
        end

        analysis.reload
      end

      Rails.logger.info("[Analysis##{analysis.id}] Pipeline completed successfully")
    rescue => e
      Rails.logger.error(
        "[Analysis##{analysis.id}] Pipeline unexpected exception: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      )
      analysis.update!(status: :failed, error_message: "Worker crashed: #{e.message}", finished_at: Time.current)
    end
  end
end
