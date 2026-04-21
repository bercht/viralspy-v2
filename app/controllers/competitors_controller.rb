class CompetitorsController < ApplicationController
  before_action :set_competitor, only: [ :show, :destroy ]

  def index
    @competitors = current_account.competitors
                                  .includes(:analyses)
                                  .order(created_at: :desc)
  end

  def new
    @competitor = current_account.competitors.build
    authorize @competitor
  end

  def create
    @competitor = current_account.competitors.build(competitor_params)
    authorize @competitor

    if @competitor.save
      redirect_to @competitor, notice: t("competitors.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    authorize @competitor
    @analyses = @competitor.analyses.order(created_at: :desc)
  end

  def destroy
    authorize @competitor
    @competitor.destroy
    redirect_to competitors_path, notice: t("competitors.destroyed")
  end

  private

  def set_competitor
    @competitor = current_account.competitors.find(params[:id])
  end

  def competitor_params
    params.require(:competitor).permit(:instagram_handle, :niche)
  end
end
