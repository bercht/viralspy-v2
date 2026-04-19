class AnalysesController < ApplicationController
  before_action :set_competitor
  before_action :set_analysis, only: [ :show ]

  def create
    @analysis = @competitor.analyses.build(account: current_account, status: :pending)
    authorize @analysis

    if @analysis.save
      Analyses::RunAnalysisWorker.perform_async(@analysis.id)
      redirect_to competitor_analysis_path(@competitor, @analysis),
                  notice: t("analyses.started")
    else
      redirect_to @competitor, alert: t("analyses.create_failed")
    end
  end

  def show
    authorize @analysis
    return unless @analysis.completed?

    @profile_metrics = @analysis.profile_metrics || {}
    @insights = @analysis.insights || {}
    @posts_by_type = @analysis.posts
                              .where(selected_for_analysis: true)
                              .group_by(&:post_type)
    @suggestions = @analysis.content_suggestions.ordered
  end

  private

  def set_competitor
    @competitor = current_account.competitors.find(params[:competitor_id])
  end

  def set_analysis
    @analysis = @competitor.analyses.find(params[:id])
  end
end
