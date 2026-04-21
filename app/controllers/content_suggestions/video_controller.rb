module ContentSuggestions
  class VideoController < ApplicationController
    before_action :set_content_suggestion

    def new
      authorize @content_suggestion, :generate_media?
      @script = MediaGeneration::ScriptBuilder.build(suggestion: @content_suggestion)
      @has_heygen_key = current_tenant.api_credentials.exists?(provider: "heygen", active: true)
    end

    private

    def set_content_suggestion
      @content_suggestion = current_tenant.content_suggestions
                                          .includes(analysis: :competitor)
                                          .find(params[:content_suggestion_id])
    end
  end
end
