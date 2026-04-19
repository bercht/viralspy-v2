class ContentSuggestionsController < ApplicationController
  before_action :set_suggestion

  def update
    authorize @suggestion

    new_status = params.dig(:content_suggestion, :status)
    unless %w[saved discarded draft].include?(new_status)
      return redirect_back_or_to(
        competitor_analysis_path(@suggestion.analysis.competitor, @suggestion.analysis),
        alert: t("content_suggestions.update_failed")
      )
    end

    if @suggestion.update(status: new_status)
      redirect_back_or_to(
        competitor_analysis_path(@suggestion.analysis.competitor, @suggestion.analysis),
        notice: t("content_suggestions.updated.#{@suggestion.status}")
      )
    else
      redirect_back_or_to(
        competitor_analysis_path(@suggestion.analysis.competitor, @suggestion.analysis),
        alert: t("content_suggestions.update_failed")
      )
    end
  end

  private

  def set_suggestion
    @suggestion = current_account.content_suggestions.find(params[:id])
  end
end
