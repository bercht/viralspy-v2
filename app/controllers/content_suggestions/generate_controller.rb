# frozen_string_literal: true

module ContentSuggestions
  class GenerateController < ApplicationController
    before_action :set_analysis

    VALID_CONTENT_TYPES = %w[reel carousel story].freeze
    MAX_QUANTITY = 3

    def create
      content_type = params[:content_type].to_s
      quantity = params[:quantity].to_i.clamp(1, MAX_QUANTITY)

      unless VALID_CONTENT_TYPES.include?(content_type)
        return redirect_back(fallback_location: root_path, alert: "Tipo de conteúdo inválido.")
      end

      playbook = @analysis.playbooks.order(created_at: :desc).first ||
                 current_tenant.playbooks.order(created_at: :desc).first

      if playbook.nil?
        return redirect_back(fallback_location: root_path,
                             alert: "Configure um Playbook antes de gerar sugestões.")
      end

      authorize PlaybookSuggestion

      result = Playbooks::GenerateSuggestionsService.call(
        playbook: playbook,
        content_type: content_type,
        quantity: quantity
      )

      if result.success?
        @playbook = playbook
        @suggestions = result.data[:suggestions]
        @content_type = content_type
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to competitor_analysis_path(@competitor, @analysis) }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "suggestions-generate-error",
              html: helpers.tag.div(result.error, id: "suggestions-generate-error",
                                    class: "rounded-card border border-semantic-danger/30 bg-semantic-danger-bg px-4 py-3 text-body-sm text-semantic-danger")
            )
          end
          format.html { redirect_back(fallback_location: root_path, alert: result.error) }
        end
      end
    end

    private

    def set_analysis
      @competitor = current_tenant.competitors.find(params[:competitor_id])
      @analysis = @competitor.analyses.find(params[:analysis_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "Análise não encontrada."
    end
  end
end
