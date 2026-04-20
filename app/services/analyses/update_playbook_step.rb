module Analyses
  class UpdatePlaybookStep
    MAX_TOKENS = 4000
    SEPARATOR = "---DIFF_SUMMARY---"

    def self.call(analysis_playbook)
      new(analysis_playbook).call
    end

    def initialize(analysis_playbook)
      @ap = analysis_playbook
      @playbook = analysis_playbook.playbook
      @analysis = analysis_playbook.analysis
      @account = @analysis.account
    end

    def call
      pending_feedbacks = PlaybookFeedback.pending_for_playbook(@playbook)
      response = call_llm(pending_feedbacks)
      content, diff_summary = parse_response(response.content)

      version_number = @playbook.current_version_number + 1
      version = PlaybookVersion.create!(
        playbook: @playbook,
        version_number: version_number,
        content: content,
        diff_summary: diff_summary,
        feedbacks_incorporated_count: pending_feedbacks.count,
        triggered_by_analysis_id: @analysis.id
      )

      incorporate_feedbacks(pending_feedbacks, version)
      @playbook.update!(current_version_number: version_number)
      @ap.playbook_update_completed!

      Analyses::Result.success(data: { version_number: version_number })
    rescue ApiCredentials::NotConfiguredError => e
      Rails.logger.error("[UpdatePlaybookStep] No credential: #{e.message} playbook_id=#{@playbook.id}")
      @ap.playbook_update_failed! rescue nil
      Analyses::Result.failure(error: e.message, error_code: :no_credential)
    rescue LLM::Error => e
      Rails.logger.error("[UpdatePlaybookStep] LLM error: #{e.message} playbook_id=#{@playbook.id}")
      @ap.playbook_update_failed! rescue nil
      Analyses::Result.failure(error: e.message, error_code: :llm_failed)
    rescue => e
      Rails.logger.error("[UpdatePlaybookStep] Unexpected error: #{e.class} - #{e.message} playbook_id=#{@playbook.id}")
      @ap.playbook_update_failed! rescue nil
      Analyses::Result.failure(error: e.message, error_code: :update_playbook_exception)
    end

    private

    def call_llm(pending_feedbacks)
      locals = {
        playbook_name: @playbook.name,
        playbook_niche: @playbook.niche.to_s,
        playbook_purpose: @playbook.purpose.to_s,
        current_version_number: @playbook.current_version_number,
        current_content: @playbook.current_content,
        competitor_handle: @analysis.competitor.instagram_handle,
        pending_feedbacks: pending_feedbacks,
        profile_metrics: @analysis.profile_metrics || {},
        insights: @analysis.insights || {}
      }

      user_prompt = PromptRenderer.render(step: "update_playbook", kind: :user, locals: locals)

      provider = provider_for_generation
      model    = model_for_generation
      key      = api_key_for(provider)

      LLM::Gateway.complete(
        provider: provider,
        model: model,
        api_key: key,
        messages: [ { role: "user", content: user_prompt } ],
        json_mode: false,
        max_tokens: MAX_TOKENS,
        temperature: 0.7,
        use_case: "update_playbook",
        account: @account,
        analysis: @analysis
      )
    end

    def parse_response(raw)
      if raw.include?(SEPARATOR)
        parts = raw.split(SEPARATOR, 2)
        content = parts[0].strip
        diff_summary = parts[1].strip
      else
        content = raw.strip
        diff_summary = "Playbook atualizado com novos insights da análise."
      end
      [ content, diff_summary ]
    end

    def incorporate_feedbacks(feedbacks, version)
      feedbacks.each do |feedback|
        feedback.update!(status: :incorporated, incorporated_in_version_id: version.id)
      end
    end

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
  end
end
