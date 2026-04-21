class GeneratedMediasController < ApplicationController
  before_action :set_content_suggestion

  def create
    authorize @content_suggestion, :generate_media?

    outcome = MediaGeneration::Start.call(
      content_suggestion: @content_suggestion,
      account: current_tenant,
      script: params.dig(:generated_media, :script),
      avatar_id: params.dig(:generated_media, :avatar_id),
      voice_id: params.dig(:generated_media, :voice_id)
    )

    if outcome.success?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "suggestion_#{@content_suggestion.id}_media",
            partial: "generated_medias/suggestion_media_slot",
            locals: { suggestion: @content_suggestion, last_media: outcome.generated_media }
          )
        end
        format.html { redirect_to competitor_analysis_path(@content_suggestion.analysis.competitor, @content_suggestion.analysis) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend(
            "suggestion_#{@content_suggestion.id}_errors",
            partial: "generated_medias/error_message",
            locals: { message: outcome.error }
          )
        end
        format.html do
          redirect_to competitor_analysis_path(@content_suggestion.analysis.competitor, @content_suggestion.analysis), alert: outcome.error
        end
      end
    end
  end

  private

  def set_content_suggestion
    @content_suggestion = current_tenant.content_suggestions.find(params[:content_suggestion_id])
  end
end
