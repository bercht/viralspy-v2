class OwnPostsController < ApplicationController
  before_action :set_own_profile
  before_action :set_own_post, only: [ :show, :edit, :update ]

  def index
    @own_posts = @own_profile.own_posts.recent
    @own_posts = @own_posts.where(post_type: params[:type]) if params[:type].present?
  end

  def show; end

  def edit; end

  def update
    if @own_post.update(own_post_params)
      redirect_to own_profile_own_post_path(@own_profile, @own_post),
        notice: "Avaliação salva."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_own_profile
    @own_profile = current_tenant.own_profiles.find(params[:own_profile_id])
  end

  def set_own_post
    @own_post = @own_profile.own_posts.find(params[:id])
  end

  def own_post_params
    params.require(:own_post).permit(
      :performance_rating,
      :performance_notes,
      :execution_notes,
      :inspired_by_suggestion_id
    )
  end
end
