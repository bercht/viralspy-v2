class PlaybookVersionsController < ApplicationController
  def index
    @playbook = current_tenant.playbooks.find(params[:playbook_id])
    authorize @playbook, :show?
    @versions = @playbook.playbook_versions.recent
  end

  def show
    @version = current_tenant.playbooks.joins(:playbook_versions)
                              .where(playbook_versions: { id: params[:id] })
                              .then { PlaybookVersion.find(params[:id]) }
    @playbook = @version.playbook
    raise ActiveRecord::RecordNotFound unless @playbook.account_id == current_tenant.id

    authorize @playbook, :show?
  end
end
