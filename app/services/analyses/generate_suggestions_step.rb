module Analyses
  class GenerateSuggestionsStep
    GENERATION_MODEL = "claude-opus-4-7"
    PROVIDER = :anthropic
    MAX_TOKENS = 4000
    TARGET_COUNT = 5

    DEFAULT_MIX = { reel: 2, carousel: 2, image: 1 }.freeze
    FALLBACK_ORDER = %i[reel carousel image].freeze

    def self.call(analysis)
      new(analysis).call
    end

    def initialize(analysis)
      @analysis = analysis
      @account = analysis.account
      @competitor = analysis.competitor
    end

    def call
      available = available_insight_types

      if available.empty?
        mark_failed("No insights available to generate suggestions")
        return Analyses::Result.failure(error: "No insights", error_code: :no_insights)
      end

      mix = resolve_mix(available)
      response = call_llm(mix: mix)
      parsed = response.parsed_json
      suggestions_data = parsed["suggestions"] || parsed[:suggestions] || []

      if suggestions_data.empty?
        mark_failed("LLM returned no suggestions")
        return Analyses::Result.failure(error: "Empty suggestions", error_code: :empty_suggestions)
      end

      persist_suggestions(suggestions_data)
      complete_analysis

      Analyses::Result.success(data: { count: suggestions_data.size, mix: mix })
    rescue LLM::ResponseParseError => e
      Rails.logger.error("[Analysis##{analysis.id}] GenerateSuggestions JSON parse: #{e.message}")
      mark_failed("LLM returned invalid JSON: #{e.message}")
      Analyses::Result.failure(error: e.message, error_code: :invalid_json)
    rescue LLM::Error => e
      Rails.logger.error("[Analysis##{analysis.id}] GenerateSuggestions LLM error: #{e.message}")
      mark_failed("LLM call failed: #{e.message}")
      Analyses::Result.failure(error: e.message, error_code: :llm_failed)
    rescue => e
      Rails.logger.error("[Analysis##{analysis.id}] GenerateSuggestions exception: #{e.class} - #{e.message}")
      mark_failed("GenerateSuggestionsStep crashed: #{e.message}")
      Analyses::Result.failure(error: e.message, error_code: :generate_exception)
    end

    private

    attr_reader :analysis, :account, :competitor

    def available_insight_types
      insights_hash = analysis.insights || {}
      %w[reels carousels images].filter_map do |key|
        next if insights_hash[key].blank? && insights_hash[key.to_sym].blank?

        case key
        when "reels" then :reel
        when "carousels" then :carousel
        when "images" then :image
        end
      end
    end

    def resolve_mix(available)
      mix = DEFAULT_MIX.dup
      mix.each_key { |type| mix[type] = 0 unless available.include?(type) }

      deficit = TARGET_COUNT - mix.values.sum
      return mix if deficit <= 0

      FALLBACK_ORDER.each do |type|
        break if deficit <= 0
        next unless available.include?(type)

        mix[type] += deficit
        deficit = 0
      end

      mix
    end

    def call_llm(mix:)
      mix_label = mix.filter_map { |type, count| "#{count} #{type}#{'s' if count != 1}" if count > 0 }.join(" + ")

      locals = {
        handle: competitor.instagram_handle,
        followers: competitor.followers_count.to_i,
        profile_metrics: analysis.profile_metrics || {},
        insights: analysis.insights || {},
        target_count: TARGET_COUNT,
        mix_label: mix_label
      }

      system_prompt = PromptRenderer.render(step: "generate_suggestions", kind: :system, locals: locals)
      user_prompt = PromptRenderer.render(step: "generate_suggestions", kind: :user, locals: locals)

      LLM::Gateway.complete(
        provider: PROVIDER,
        model: GENERATION_MODEL,
        messages: [ { role: "user", content: user_prompt } ],
        system: system_prompt,
        json_mode: true,
        max_tokens: MAX_TOKENS,
        temperature: 0.8,
        use_case: "content_suggestions",
        account: account,
        analysis: analysis
      )
    end

    def persist_suggestions(suggestions_data)
      suggestions_data.each_with_index do |data, i|
        ContentSuggestion.create!(
          analysis: analysis,
          account: account,
          position: data["position"] || data[:position] || (i + 1),
          content_type: data["content_type"] || data[:content_type],
          hook: data["hook"] || data[:hook],
          caption_draft: data["caption_draft"] || data[:caption_draft],
          format_details: data["format_details"] || data[:format_details] || {},
          suggested_hashtags: data["suggested_hashtags"] || data[:suggested_hashtags] || [],
          rationale: data["rationale"] || data[:rationale],
          status: :draft
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("[Analysis##{analysis.id}] Skipping invalid suggestion at position #{i + 1}: #{e.message}")
      end
    end

    def complete_analysis
      analysis.update!(status: :completed, finished_at: Time.current)
      Rails.logger.info("[Analysis##{analysis.id}] Analysis completed successfully")
    end

    def mark_failed(message)
      analysis.update!(status: :failed, error_message: message, finished_at: Time.current)
    end
  end
end
