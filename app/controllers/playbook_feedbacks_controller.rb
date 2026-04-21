class PlaybookFeedbacksController < ApplicationController
  before_action :set_playbook, only: [ :create ]
  before_action :set_feedback, only: [ :incorporate, :dismiss ]

  def create
    @feedback = @playbook.playbook_feedbacks.build(
      feedback_params.merge(account: current_tenant)
    )
    @feedback.source = :manual

    if @feedback.save
      redirect_to @playbook, notice: "Feedback registrado."
    else
      redirect_to @playbook, alert: "Erro ao registrar feedback."
    end
  end

  def incorporate
    @feedback.status_incorporated!
    redirect_back fallback_location: @feedback.playbook, notice: "Feedback marcado como incorporado."
  end

  def dismiss
    @feedback.status_dismissed!
    redirect_back fallback_location: @feedback.playbook, notice: "Feedback descartado."
  end

  private

  def set_playbook
    @playbook = current_tenant.playbooks.find(params[:playbook_id])
    authorize @playbook, :update?
  end

  def set_feedback
    @feedback = current_tenant.playbook_feedbacks.find(params[:id])
    authorize @feedback, :update?
  end

  def feedback_params
    params.require(:playbook_feedback).permit(:content)
  end
end
