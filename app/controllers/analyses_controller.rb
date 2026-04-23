class AnalysesController < ApplicationController
  include RequiresApiCredentials
  include AnalysesHelper

  before_action :set_competitor
  before_action :require_competitor_niche!, only: [ :new, :create ]
  before_action :require_playbook!, only: [ :new, :create ]
  before_action :require_api_credentials_configured!, only: [ :new, :create ]
  before_action :set_analysis, only: [ :show, :export_top_posts, :extend_expiry, :discard ]

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
      attach_playbooks(@analysis)
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

  def extend_expiry
    authorize @analysis, :update?

    @analysis.extend_expiry!(30)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "analysis-expiry-#{@analysis.id}",
          partial: "analyses/expiry_banner",
          locals: { analysis: @analysis }
        )
      end
      format.html { redirect_back fallback_location: competitor_path(@competitor) }
    end
  end

  def discard
    authorize @analysis, :destroy?

    @analysis.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("analysis-row-#{@analysis.id}")
      end
      format.html { redirect_to competitor_path(@competitor), notice: t("analyses.flash.discarded") }
    end
  end

  def export_top_posts
    authorize @analysis, :show?

    content = Analyses::TopPostsExporter.new(@analysis).call
    filename = "viralspy_top_posts_#{@analysis.competitor.instagram_handle}_#{@analysis.id}.txt"

    send_data content,
              filename:,
              type: "text/plain; charset=utf-8",
              disposition: "attachment"
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

  def require_competitor_niche!
    return if @competitor.niche.present?

    redirect_to edit_competitor_path(@competitor),
                alert: t("analyses.errors.competitor_niche_missing")
  end

  def require_playbook!
    return if current_account.playbooks.any?

    redirect_to new_playbook_path,
                alert: t("analyses.errors.no_playbook")
  end

  def attach_playbooks(analysis)
    playbook_ids = params.dig(:analysis, :playbook_ids)
    return unless playbook_ids.present?

    ids = playbook_ids.reject(&:blank?).map(&:to_i)
    current_tenant.playbooks.where(id: ids).each do |playbook|
      analysis.analysis_playbooks.create!(playbook: playbook)
    end
  end
end
