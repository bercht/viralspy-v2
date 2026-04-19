module Analyses
  class ProfileMetricsStep
    def self.call(analysis)
      new(analysis).call
    end

    def initialize(analysis)
      @analysis = analysis
    end

    def call
      posts = analysis.posts.to_a
      return success_with_empty_metrics if posts.empty?

      metrics = {
        period_analyzed_days:      period_days(posts),
        posts_per_week:            posts_per_week(posts),
        content_mix:               content_mix(posts),
        avg_likes_per_post:        avg(posts.map(&:likes_count)),
        avg_comments_per_post:     avg(posts.map(&:comments_count)),
        avg_engagement_rate:       avg_engagement_rate(posts),
        top_hashtags:              top_hashtags(posts),
        best_posting_days:         best_posting_days(posts),
        best_posting_hours:        best_posting_hours(posts),
        posting_consistency_score: consistency_score(posts)
      }

      analysis.update!(profile_metrics: metrics)
      Rails.logger.info(
        "[Analysis##{analysis.id}] ProfileMetricsStep computed metrics for #{posts.size} posts"
      )

      Analyses::Result.success(data: { metrics: metrics })
    rescue => e
      Rails.logger.error(
        "[Analysis##{analysis.id}] ProfileMetricsStep exception: #{e.class} - #{e.message}"
      )
      Analyses::Result.failure(error: e.message, error_code: :metrics_exception)
    end

    private

    attr_reader :analysis

    def success_with_empty_metrics
      analysis.update!(profile_metrics: { posts_analyzed: 0 })
      Analyses::Result.success(data: { metrics: {} })
    end

    def period_days(posts)
      dated = posts.select(&:posted_at)
      return 0 if dated.empty?

      ((dated.map(&:posted_at).max - dated.map(&:posted_at).min) / 1.day).ceil
    end

    def posts_per_week(posts)
      days = period_days(posts)
      return 0.0 if days <= 0

      (posts.size.to_f / days * 7).round(2)
    end

    def content_mix(posts)
      total = posts.size.to_f
      grouped = posts.group_by(&:post_type).transform_values { |v| (v.size / total).round(3) }
      { "reel" => 0.0, "carousel" => 0.0, "image" => 0.0 }.merge(grouped)
    end

    def avg(values)
      return 0 if values.empty?

      (values.sum.to_f / values.size).round
    end

    def avg_engagement_rate(posts)
      followers = analysis.competitor.followers_count.to_i
      return 0.0 if followers <= 0 || posts.empty?

      rates = posts.map { |p| (p.likes_count + p.comments_count).to_f / followers }
      (rates.sum / rates.size).round(4)
    end

    def top_hashtags(posts)
      hashtags = posts.flat_map(&:hashtags).compact.map(&:downcase)
      return [] if hashtags.empty?

      counts = hashtags.tally
      counts.sort_by { |_tag, count| -count }.first(10).map(&:first)
    end

    def best_posting_days(posts)
      dated = posts.select(&:posted_at)
      return [] if dated.empty?

      tally = dated.map { |p| p.posted_at.strftime("%A") }.tally
      tally.sort_by { |_day, count| -count }.first(3).map(&:first)
    end

    def best_posting_hours(posts)
      dated = posts.select(&:posted_at)
      return [] if dated.empty?

      tally = dated.map { |p| p.posted_at.in_time_zone.hour }.tally
      tally.sort_by { |_hour, count| -count }.first(3).map(&:first)
    end

    def consistency_score(posts)
      dated = posts.select(&:posted_at).sort_by(&:posted_at)
      return 0.0 if dated.size < 3

      intervals = dated.each_cons(2).map { |a, b| (b.posted_at - a.posted_at).to_f }
      return 0.0 if intervals.empty?

      mean = intervals.sum / intervals.size
      return 0.0 if mean.zero?

      variance = intervals.sum { |i| (i - mean)**2 } / intervals.size
      std_dev = Math.sqrt(variance)
      cv = std_dev / mean
      [ 1.0 - cv, 0.0 ].max.round(2)
    end
  end
end
