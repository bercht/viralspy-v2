module Analyses
  class ScoreAndSelectStep
    SELECTION_LIMITS = {
      "reel"     => 12,
      "carousel" => 5,
      "image"    => 3
    }.freeze

    def self.call(analysis)
      new(analysis).call
    end

    def initialize(analysis)
      @analysis = analysis
      @competitor = analysis.competitor
    end

    def call
      ActiveRecord::Base.transaction do
        score_all_posts
        select_top_per_type
        update_analysis_state
      end

      Analyses::Result.success(
        data: { posts_selected: analysis.posts.where(selected_for_analysis: true).count }
      )
    rescue => e
      Rails.logger.error(
        "[Analysis##{analysis.id}] ScoreAndSelectStep exception: #{e.class} - #{e.message}"
      )
      mark_failed("ScoreAndSelectStep crashed: #{e.message}")
      Analyses::Result.failure(error: e.message, error_code: :scoring_exception)
    end

    private

    attr_reader :analysis, :competitor

    def score_all_posts
      followers = competitor.followers_count.to_i
      analysis.posts.find_each do |post|
        score = Analyses::Scoring::Formula.calculate(post: post, followers: followers)
        post.update!(quality_score: score)
      end
    end

    def select_top_per_type
      SELECTION_LIMITS.each do |type, limit|
        top_ids = analysis.posts
                          .where(post_type: type)
                          .where("quality_score > 0")
                          .order(quality_score: :desc)
                          .limit(limit)
                          .pluck(:id)

        next if top_ids.empty?

        analysis.posts.where(id: top_ids).update_all(selected_for_analysis: true)
        Rails.logger.info(
          "[Analysis##{analysis.id}] Selected #{top_ids.size} #{type}(s) for analysis"
        )
      end
    end

    def update_analysis_state
      selected_count = analysis.posts.where(selected_for_analysis: true).count

      analysis.update!(
        status: :transcribing,
        posts_analyzed_count: selected_count
      )

      Rails.logger.info(
        "[Analysis##{analysis.id}] ScoreAndSelectStep completed: #{selected_count} posts selected"
      )
    end

    def mark_failed(message)
      analysis.update!(status: :failed, error_message: message, finished_at: Time.current)
    end
  end
end
