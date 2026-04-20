class AnalysesController < ApplicationController
  include RequiresApiCredentials
  include AnalysesHelper

  before_action :set_competitor
  before_action :require_api_credentials_configured!, only: [ :new, :create ]
  before_action :set_analysis, only: [ :show ]

  def new
    @analysis = @competitor.analyses.build(
      account: current_account,
      max_posts: Analysis.columns_hash["max_posts"].default.to_i
    )
    authorize @analysis
  end

  def create
    @analysis = @competitor.analyses.build(
      analysis_params.merge(account: current_account, status: :pending)
    )
    authorize @analysis

    if @analysis.save
      Analyses::RunAnalysisWorker.perform_async(@analysis.id)
      redirect_to competitor_analysis_path(@competitor, @analysis),
                  notice: t("analyses.flash.started")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize @analysis
  end

  private

  def set_competitor
    @competitor = current_account.competitors.find(params[:competitor_id])
  end

  def set_analysis
    @analysis = @competitor.analyses.find(params[:id])
  end

  def analysis_params
    params.fetch(:analysis, {}).permit(:max_posts)
  end
end
