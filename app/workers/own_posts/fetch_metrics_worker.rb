module OwnPosts
  class FetchMetricsWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'default', retry: 3

    def perform(own_post_id)
      own_post = OwnPost.find_by(id: own_post_id)
      return unless own_post
      return unless own_post.own_profile.token_valid?

      ActsAsTenant.with_tenant(own_post.account) do
        api = Meta::GraphApi.new(access_token: own_post.own_profile.meta_access_token)

        metric_names = case own_post.post_type
                       when 'reel'     then Meta::GraphApi::REEL_METRICS
                       when 'carousel' then Meta::GraphApi::CAROUSEL_METRICS
                       when 'story'    then Meta::GraphApi::STORY_METRICS
                       else                 Meta::GraphApi::IMAGE_METRICS
                       end

        metrics = api.fetch_post_insights(own_post.instagram_post_id, metric_names: metric_names)
        own_post.add_metrics_snapshot(metrics)
        own_post.save!

        Rails.logger.info(
          "OwnPosts::FetchMetricsWorker completed — " \
          "own_post_id=#{own_post_id} metrics_keys=#{metrics.keys}"
        )
      end

    rescue Meta::GraphApi::AuthenticationError => e
      Rails.logger.warn(
        "OwnPosts::FetchMetricsWorker token inválido — " \
        "own_post_id=#{own_post_id} error=#{e.message}"
      )
    rescue => e
      Rails.logger.error(
        "OwnPosts::FetchMetricsWorker failed — " \
        "own_post_id=#{own_post_id} error=#{e.message}"
      )
      raise
    end
  end
end
