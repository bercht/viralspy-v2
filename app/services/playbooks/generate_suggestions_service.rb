# frozen_string_literal: true

module Playbooks
  class GenerateSuggestionsService
    HISTORY_LIMIT = 20

    def self.call(playbook:, content_type:, quantity:)
      new(playbook:, content_type:, quantity:).call
    end

    def initialize(playbook:, content_type:, quantity:)
      @playbook = playbook
      @content_type = content_type
      @quantity = quantity
      @account = playbook.account
    end

    def call
      if @playbook.current_version_number == 0
        return Analyses::Result.failure(
          error: "Este playbook ainda não tem conteúdo suficiente. Rode ao menos uma análise primeiro.",
          error_code: :no_content
        )
      end

      provider = provider_for_generation
      model = model_for_generation
      key = api_key_for(provider)

      user_prompt = Analyses::PromptRenderer.render(
        step: "playbook_suggestions",
        kind: :user,
        locals: {
          playbook_name: @playbook.name,
          playbook_niche: @playbook.niche.to_s,
          playbook_purpose: @playbook.purpose.to_s,
          current_content: @playbook.current_content,
          content_type: @content_type,
          quantity: @quantity,
          previous_suggestions: previous_suggestions
        }
      )

      response = LLM::Gateway.complete(
        provider: provider,
        model: model,
        api_key: key,
        messages: [ { role: "user", content: user_prompt } ],
        json_mode: true,
        max_tokens: 2000,
        temperature: 0.8,
        use_case: "playbook_suggestions",
        account: @account,
        analysis: nil
      )

      items = parse_suggestions(response.content)
      suggestions = persist_suggestions(items)

      Analyses::Result.success(data: { suggestions: suggestions })
    rescue ApiCredentials::NotConfiguredError => e
      Analyses::Result.failure(error: e.message, error_code: :no_credential)
    rescue LLM::Error => e
      Rails.logger.error("[Playbooks::GenerateSuggestionsService] LLM error: #{e.message}")
      Analyses::Result.failure(error: e.message, error_code: :llm_failed)
    rescue JSON::ParserError => e
      Rails.logger.error("[Playbooks::GenerateSuggestionsService] Parse error: #{e.message}")
      Analyses::Result.failure(error: "Resposta inválida do modelo de linguagem.", error_code: :parse_error)
    rescue => e
      Rails.logger.error("[Playbooks::GenerateSuggestionsService] Unexpected error: #{e.class} - #{e.message}")
      Analyses::Result.failure(error: "Erro inesperado ao gerar sugestões.", error_code: :unexpected_error)
    end

    private

    def provider_for_generation
      @account.llm_preferences_with_defaults["generation_provider"].to_sym
    end

    def model_for_generation
      @account.llm_preferences_with_defaults["generation_model"]
    end

    def api_key_for(provider)
      credential = @account.api_credential_for(provider.to_s)
      raise ApiCredentials::NotConfiguredError.new(provider: provider.to_s, use_case: "generation") unless credential
      credential.encrypted_api_key
    end

    def parse_suggestions(raw)
      cleaned = raw.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "").strip
      data = JSON.parse(cleaned)
      data["suggestions"] || []
    end

    def persist_suggestions(items)
      items.map do |item|
        PlaybookSuggestion.create!(
          playbook: @playbook,
          account: @account,
          content_type: @content_type,
          hook: item["hook"],
          caption_draft: item["caption_draft"],
          format_details: item["format_details"] || {},
          suggested_hashtags: item["suggested_hashtags"] || [],
          rationale: item["rationale"]
        )
      end
    end

    def previous_suggestions
      @previous_suggestions ||= @playbook.playbook_suggestions
        .visible
        .where(content_type: @content_type)
        .order(created_at: :desc)
        .limit(HISTORY_LIMIT)
        .select(:hook, :rationale, :caption_draft)
        .filter_map do |suggestion|
          hook = previous_suggestion_hook(suggestion)
          next if hook.blank?

          {
            hook: hook,
            rationale: suggestion.rationale.to_s
          }
        end
    end

    def previous_suggestion_hook(suggestion)
      hook = suggestion.hook.to_s.strip
      return hook if hook.present?

      caption_fallback = suggestion.caption_draft.to_s.squish
      return if caption_fallback.blank?

      caption_fallback.first(80)
    end
  end
end
