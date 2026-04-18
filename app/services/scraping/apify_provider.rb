module Scraping
  class ApifyProvider < BaseProvider
    PROFILE_ACTOR_ID = "apify~instagram-profile-scraper".freeze
    POST_ACTOR_ID    = "apify~instagram-post-scraper".freeze

    RETRYABLE_ERRORS = [ Scraping::RateLimitError, Scraping::TimeoutError ].freeze
    RETRY_BACKOFF_SECONDS = 2

    def initialize(client: Scraping::Apify::Client.new, sleeper: ->(s) { sleep s })
      @client = client
      @sleeper = sleeper
    end

    def scrape_profile(handle:, max_posts:)
      normalized_handle = validate_handle!(handle)
      max_posts = Integer(max_posts)

      profile_run_id = nil
      posts_run_id   = nil

      with_retry do
        profile_run = client.start_run(
          actor_id: PROFILE_ACTOR_ID,
          input: profile_input(normalized_handle, max_posts)
        )
        profile_run_id = profile_run["id"]

        poller_for(profile_run_id).wait_for_completion!
        profile_items = client.get_dataset_items(profile_run_id)

        if profile_items.blank?
          return Scraping::Result.failure(
            error: :profile_not_found,
            message: "profile '#{normalized_handle}' returned no data",
            run_id: profile_run_id
          )
        end

        profile_data = Scraping::Apify::Parser.parse_profile(profile_items.first)
        post_urls = Array(profile_data[:recent_post_urls]).first(max_posts)

        if post_urls.empty?
          return Scraping::Result.success(
            posts: [],
            profile_data: profile_data,
            run_id: profile_run_id
          )
        end

        post_run = client.start_run(
          actor_id: POST_ACTOR_ID,
          input: post_input(post_urls, normalized_handle)
        )
        posts_run_id = post_run["id"]

        poller_for(posts_run_id).wait_for_completion!
        post_items = client.get_dataset_items(posts_run_id)

        posts = Scraping::Apify::Parser.parse_posts(post_items)

        Scraping::Result.success(
          posts: posts,
          profile_data: profile_data,
          run_id: posts_run_id
        )
      end
    rescue Scraping::ProfileNotFoundError => e
      Scraping::Result.failure(error: :profile_not_found, message: e.message,
                                run_id: profile_run_id || posts_run_id)
    rescue Scraping::RunFailedError => e
      Scraping::Result.failure(error: :run_failed, message: e.message,
                                run_id: profile_run_id || posts_run_id)
    rescue Scraping::TimeoutError => e
      Scraping::Result.failure(error: :timeout, message: e.message,
                                run_id: profile_run_id || posts_run_id)
    rescue Scraping::RateLimitError => e
      Scraping::Result.failure(error: :rate_limited, message: e.message,
                                run_id: profile_run_id || posts_run_id)
    rescue Scraping::ParseError => e
      Scraping::Result.failure(error: :parse_error, message: e.message,
                                run_id: profile_run_id || posts_run_id)
    rescue Scraping::Error => e
      Scraping::Result.failure(error: :unknown, message: e.message,
                                run_id: profile_run_id || posts_run_id)
    end

    private

    attr_reader :client, :sleeper

    def profile_input(handle, max_posts)
      {
        "usernames"     => [ handle ],
        "resultsLimit" => max_posts
      }
    end

    def post_input(urls, handle)
      {
        "username"     => [ handle ],
        "directUrls"   => urls,
        "resultsLimit" => urls.size
      }
    end

    def poller_for(run_id)
      Scraping::Apify::RunPoller.new(
        client: client,
        run_id: run_id,
        sleeper: sleeper
      )
    end

    def with_retry
      attempts = 0
      begin
        attempts += 1
        yield
      rescue *RETRYABLE_ERRORS => e
        if attempts < 2
          Rails.logger.warn("ApifyProvider retrying after #{e.class}: #{e.message}")
          sleeper.call(RETRY_BACKOFF_SECONDS)
          retry
        end
        raise
      end
    end
  end
end
