class StoryObservationsController < ApplicationController
  before_action :set_competitor

  def index
    @story_observations = @competitor.story_observations.recent
  end

  def new
    @story_observation = @competitor.story_observations.build(observed_on: Date.today)
  end

  def create
    @story_observation = @competitor.story_observations.build(story_observation_params)
    @story_observation.account = current_tenant

    if @story_observation.save
      redirect_to competitor_story_observations_path(@competitor),
        notice: "Observação registrada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @story_observation = @competitor.story_observations.find(params[:id])
    @story_observation.destroy
    redirect_to competitor_story_observations_path(@competitor),
      notice: "Observação removida."
  end

  private

  def set_competitor
    @competitor = current_tenant.competitors.find(params[:competitor_id])
  end

  def story_observation_params
    params.require(:story_observation).permit(
      :observed_on, :format, :theme, :description,
      :perceived_engagement, :notes
    )
  end
end
