module Analyses
  class ScrapeStep
    def self.call(analysis)
      new(analysis).call
    end

    def initialize(analysis)
      @analysis = analysis
      @account = analysis.account
      @competitor = analysis.competitor
    end

    def call
      mark_started
      scraping_result = run_scraper
      return handle_scraping_failure(scraping_result) if scraping_result.failure?

      ActiveRecord::Base.transaction do
        update_competitor(scraping_result.profile_data)
        persist_posts(scraping_result.posts)
        advance_status
      end

      Analyses::Result.success(
        data: {
          posts_scraped: analysis.posts_scraped_count,
          profile: scraping_result.profile_data
        }
      )
    rescue => e
      Rails.logger.error("[Analysis##{analysis.id}] ScrapeStep exception: #{e.class} - #{e.message}")
      mark_failed("ScrapeStep crashed: #{e.message}")
      Analyses::Result.failure(error: e.message, error_code: :scrape_exception)
    end

    private

    attr_reader :analysis, :account, :competitor

    def mark_started
      analysis.update!(
        status: :scraping,
        started_at: analysis.started_at || Time.current,
        scraping_provider: ENV.fetch("SCRAPING_PROVIDER", "apify")
      )
      Rails.logger.info("[Analysis##{analysis.id}] Starting ScrapeStep for @#{competitor.instagram_handle}")
    end

    def run_scraper
      provider = Scraping::Factory.build
      max_posts = ENV.fetch("SCRAPING_POSTS_PER_ANALYSIS", "30").to_i
      provider.scrape_profile(handle: competitor.instagram_handle, max_posts: max_posts)
    end

    def handle_scraping_failure(result)
      message = result.message || result.error.to_s
      Rails.logger.warn("[Analysis##{analysis.id}] ScrapeStep failed: #{message}")
      mark_failed("Scraping failed: #{message}")
      Analyses::Result.failure(error: message, error_code: :scraping_failed)
    end

    def update_competitor(profile_data)
      return unless profile_data.present?

      competitor.update!(
        full_name:       profile_data[:full_name],
        bio:             profile_data[:bio],
        followers_count: profile_data[:followers_count],
        following_count: profile_data[:following_count],
        posts_count:     profile_data[:posts_count],
        profile_pic_url: profile_data[:profile_pic_url],
        last_scraped_at: Time.current
      )
    end

    def persist_posts(posts_array)
      posts_array.each do |post_hash|
        post = build_post_from_hash(post_hash)
        unless post.save
          Rails.logger.warn(
            "[Analysis##{analysis.id}] Failed to persist post #{post_hash[:instagram_post_id]}: #{post.errors.full_messages.join(', ')}"
          )
        end
      end

      analysis.update!(posts_scraped_count: analysis.posts.count)
      Rails.logger.info("[Analysis##{analysis.id}] ScrapeStep persisted #{analysis.posts_scraped_count} posts")
    end

    def build_post_from_hash(h)
      Post.new(
        analysis:               analysis,
        account:                account,
        competitor:             competitor,
        instagram_post_id:      h[:instagram_post_id],
        shortcode:              h[:shortcode],
        post_type:              h[:post_type],
        caption:                h[:caption],
        display_url:            h[:display_url],
        video_url:              h[:video_url],
        likes_count:            h[:likes_count] || 0,
        comments_count:         h[:comments_count] || 0,
        video_view_count:       h[:video_view_count],
        hashtags:               h[:hashtags] || [],
        mentions:               h[:mentions] || [],
        posted_at:              h[:posted_at]
      )
    end

    def advance_status
      analysis.update!(status: :scoring)
      Rails.logger.info("[Analysis##{analysis.id}] ScrapeStep completed, advancing to scoring")
    end

    def mark_failed(message)
      analysis.update!(status: :failed, error_message: message, finished_at: Time.current)
    end
  end
end
