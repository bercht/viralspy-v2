module Analyses
  class AnalyzeStep
    MAX_TOKENS = 2000

    TYPE_CONFIG = {
      reel: { dir: "analyze_reels", key: "reels", use_case: "reel_analysis" },
      carousel: { dir: "analyze_carousels", key: "carousels", use_case: "carousel_analysis" },
      image: { dir: "analyze_images", key: "images", use_case: "image_analysis" }
    }.freeze

    def self.call(analysis)
      new(analysis).call
    end

    def initialize(analysis)
      @analysis = analysis
      @account = analysis.account
      @competitor = analysis.competitor
      @insights = {}
      @failures = []
    end

    def call
      analysis.update!(status: :analyzing)

      %i[reel carousel image].each { |type| analyze_type(type) }

      if all_failed?
        mark_failed("All AnalyzeStep calls failed: #{failures.join('; ')}")
        return Analyses::Result.failure(error: "All 3 LLM analysis calls failed", error_code: :analyze_all_failed)
      end

      analysis.update!(insights: insights, status: :generating_suggestions)
      Rails.logger.info("[Analysis##{analysis.id}] AnalyzeStep completed: #{insights.keys.join(', ')}")

      Analyses::Result.success(data: { insights: insights, failures: failures })
    rescue => e
      Rails.logger.error("[Analysis##{analysis.id}] AnalyzeStep exception: #{e.class} - #{e.message}")
      mark_failed("AnalyzeStep crashed: #{e.message}")
      Analyses::Result.failure(error: e.message, error_code: :analyze_exception)
    end

    private

    attr_reader :analysis, :account, :competitor, :insights, :failures

    def analyze_type(type)
      config = TYPE_CONFIG[type]
      posts = selected_posts_of_type(type)

      if posts.empty?
        Rails.logger.info("[Analysis##{analysis.id}] Skipping #{type} analysis: no selected posts")
        return
      end

      response = call_llm(type: type, posts: posts, config: config)
      parsed = response.parsed_json
      insights[config[:key]] = parsed

      Rails.logger.info("[Analysis##{analysis.id}] #{type} analysis: #{posts.size} posts → #{parsed.keys}")
    rescue LLM::ResponseParseError => e
      record_failure(type, "JSON inválido: #{e.message}")
    rescue LLM::Error => e
      record_failure(type, "LLM error (#{e.class.name.demodulize}): #{e.message}")
    rescue => e
      record_failure(type, "Unexpected: #{e.class.name.demodulize} - #{e.message}")
    end

    def selected_posts_of_type(type)
      analysis.posts
              .where(post_type: type, selected_for_analysis: true)
              .order(quality_score: :desc)
              .to_a
    end

    def call_llm(type:, posts:, config:)
      locals = {
        handle: competitor.instagram_handle,
        followers: competitor.followers_count.to_i,
        profile_metrics: analysis.profile_metrics || {},
        posts: posts
      }

      system_prompt = PromptRenderer.render(step: config[:dir], kind: :system, locals: locals)
      user_prompt = PromptRenderer.render(step: config[:dir], kind: :user, locals: locals)

      provider = provider_for(config[:use_case])
      model    = model_for(config[:use_case])
      key      = api_key_for(provider)

      LLM::Gateway.complete(
        provider: provider,
        model: model,
        api_key: key,
        messages: [ { role: "user", content: user_prompt } ],
        system: system_prompt,
        json_mode: true,
        max_tokens: MAX_TOKENS,
        temperature: nil,
        use_case: config[:use_case],
        account: account,
        analysis: analysis
      )
    end

    # =========================================================================
    # Resolução de provider/model/key via account (BYOK — ADR-013).
    # Todos os 3 use_cases (reel_analysis, carousel_analysis, image_analysis)
    # caem no grupo "analysis". Geração de sugestões é tratada em outro step.
    # =========================================================================

    def provider_for(_use_case)
      account.llm_preferences_with_defaults["analysis_provider"].to_sym
    end

    def model_for(_use_case)
      account.llm_preferences_with_defaults["analysis_model"]
    end

    def api_key_for(provider)
      credential = account.api_credential_for(provider.to_s)
      raise ApiCredentials::NotConfiguredError.new(provider: provider.to_s, use_case: "analysis") unless credential

      credential.encrypted_api_key
    end

    def record_failure(type, message)
      msg = "#{type}: #{message}"
      failures << msg
      Rails.logger.warn("[Analysis##{analysis.id}] AnalyzeStep partial failure in #{type}: #{message}")
    end

    def all_failed?
      insights.empty? && failures.any?
    end

    def mark_failed(message)
      analysis.update!(status: :failed, error_message: message, finished_at: Time.current)
    end
  end
end
