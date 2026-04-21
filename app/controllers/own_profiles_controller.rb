class OwnProfilesController < ApplicationController
  before_action :set_own_profile, only: [:show, :edit, :update, :destroy, :sync]

  def index
    @own_profiles = current_tenant.own_profiles.order(created_at: :desc)
  end

  def show
    @own_posts = @own_profile.own_posts.recent.limit(20)
    @metrics_summary = build_metrics_summary(@own_profile)
  end

  def new
    @own_profile = current_tenant.own_profiles.build
  end

  def create
    @own_profile = current_tenant.own_profiles.build(own_profile_params)
    if @own_profile.save
      redirect_to @own_profile, notice: 'Perfil adicionado. Configure o token Meta para sincronizar posts.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @own_profile.update(own_profile_params)
      redirect_to @own_profile, notice: 'Perfil atualizado.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @own_profile.destroy
    redirect_to own_profiles_path, notice: 'Perfil removido.'
  end

  def sync
    unless @own_profile.token_valid?
      redirect_to edit_own_profile_path(@own_profile),
        alert: 'Token Meta inválido ou expirado. Atualize o token antes de sincronizar.'
      return
    end

    result = OwnProfiles::SyncPostsService.new(@own_profile).call

    if result.success?
      synced = result.data[:synced]
      redirect_to @own_profile,
        notice: "Sincronização concluída. #{synced} post(s) sincronizado(s)."
    else
      redirect_to @own_profile,
        alert: "Erro na sincronização: #{result.error}"
    end
  end

  private

  def set_own_profile
    @own_profile = current_tenant.own_profiles.find(params[:id])
  end

  def own_profile_params
    params.require(:own_profile).permit(
      :instagram_handle,
      :full_name,
      :bio,
      :voice_notes,
      :meta_access_token,
      :meta_token_expires_at
    )
  end

  def build_metrics_summary(own_profile)
    posts = own_profile.own_posts.where.not(metrics: {})
    return {} if posts.empty?

    {
      total_posts:     posts.count,
      avg_reach:       posts.average("(metrics->>'reach')::float")&.round,
      avg_plays:       posts.where(post_type: :reel).average("(metrics->>'plays')::float")&.round,
      avg_engagement:  posts.average("(metrics->>'engagement_rate')::float")&.round(4),
      top_post:        posts.order("(metrics->>'reach')::float DESC").first
    }
  end
end
