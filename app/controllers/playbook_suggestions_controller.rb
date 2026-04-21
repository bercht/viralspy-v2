class PlaybookSuggestionsController < ApplicationController
  before_action :set_playbook
  before_action :set_suggestion, only: [:update]

  def create
    authorize PlaybookSuggestion
    result = Playbooks::GenerateSuggestionsService.call(
      playbook: @playbook,
      content_type: params[:content_type],
      quantity: params[:quantity].to_i
    )

    if result.success?
      @suggestions = result.data[:suggestions]
      respond_to do |format|
        format.turbo_stream
      end
    else
      @error = result.error
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "playbook_suggestions_error",
            partial: "playbook_suggestions/error",
            locals: { error: @error }
          )
        end
      end
    end
  end

  def update
    authorize @suggestion
    allowed_statuses = %w[saved discarded]
    unless allowed_statuses.include?(params[:status])
      head :unprocessable_entity
      return
    end
    @suggestion.update!(status: params[:status])
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def set_playbook
    @playbook = current_tenant.playbooks.find(params[:playbook_id])
  end

  def set_suggestion
    @suggestion = current_tenant.playbook_suggestions.find(params[:id])
  end
end
