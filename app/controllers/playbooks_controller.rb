class PlaybooksController < ApplicationController
  before_action :set_playbook, only: [ :show, :edit, :update, :destroy, :export ]

  def index
    @playbooks = current_tenant.playbooks.recent.includes(:playbook_versions)
  end

  def show
    @current_version = @playbook.current_version
    @pending_feedbacks = @playbook.playbook_feedbacks.status_pending.order(created_at: :desc)
    @recent_versions = @playbook.playbook_versions.recent.limit(10)
    @recent_analyses = @playbook.analyses.order(created_at: :desc).limit(5)
  end

  def new
    @playbook = current_tenant.playbooks.build
    authorize @playbook
  end

  def create
    @playbook = current_tenant.playbooks.build(playbook_params)
    authorize @playbook
    if @playbook.save
      redirect_to @playbook, notice: "Playbook criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @playbook.update(playbook_params)
      redirect_to @playbook, notice: "Playbook atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @playbook.destroy
    redirect_to playbooks_path, notice: "Playbook removido."
  end

  def export
    version = @playbook.current_version
    if version
      send_data export_content(version),
        filename: "playbook-#{@playbook.name.parameterize}-v#{version.version_number}.md",
        type: "text/markdown",
        disposition: "attachment"
    else
      redirect_to @playbook, alert: "Nenhuma versão disponível para export."
    end
  end

  private

  def set_playbook
    @playbook = current_tenant.playbooks.find(params[:id])
    authorize @playbook
  end

  def playbook_params
    params.require(:playbook).permit(:name, :niche, :purpose, :author_role, :target_audience)
  end

  def export_content(version)
    <<~MARKDOWN
      ---
      playbook: #{@playbook.name}
      niche: #{@playbook.niche}
      version: #{version.version_number}
      exported_at: #{Time.current.iso8601}
      ---

      #{version.content}
    MARKDOWN
  end
end
