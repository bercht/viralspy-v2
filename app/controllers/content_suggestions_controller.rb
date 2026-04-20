class ContentSuggestionsController < ApplicationController
  before_action :set_suggestion

  def update
    authorize @suggestion

    new_status = params.dig(:content_suggestion, :status)

    unless %w[saved discarded draft].include?(new_status)
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_back_or_to fallback_path, alert: t("content_suggestions.update_failed") }
      end
      return
    end

    if @suggestion.update(status: new_status)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back_or_to fallback_path, notice: t("content_suggestions.updated.#{@suggestion.status}") }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_back_or_to fallback_path, alert: t("content_suggestions.update_failed") }
      end
    end
  end

  private

  def set_suggestion
    @suggestion = current_account.content_suggestions.find(params[:id])
  end

  def fallback_path
    competitor_analysis_path(@suggestion.analysis.competitor, @suggestion.analysis)
  end
end
