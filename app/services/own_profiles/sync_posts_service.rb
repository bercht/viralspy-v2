module OwnProfiles
  class SyncPostsService
    MEDIA_TYPE_MAP = {
      'REEL'           => 'reel',
      'CAROUSEL_ALBUM' => 'carousel',
      'IMAGE'          => 'image',
      'VIDEO'          => 'reel'
    }.freeze

    def initialize(own_profile)
      @own_profile = own_profile
      @account     = own_profile.account
    end

    def call
      unless @own_profile.token_valid?
        return OwnProfiles::Result.failure(
          error: 'Token ausente ou expirado',
          error_code: :invalid_token
        )
      end

      api = Meta::GraphApi.new(access_token: @own_profile.meta_access_token)

      raw_posts = fetch_media(api)
      if raw_posts.empty?
        return OwnProfiles::Result.failure(error: 'Nenhum post retornado pela API')
      end

      synced_count = 0
      failed_count = 0

      raw_posts.each do |raw|
        sync_single_post(api, raw)
        synced_count += 1
      rescue => e
        Rails.logger.error(
          "OwnProfiles::SyncPostsService post sync failed — " \
          "instagram_post_id=#{raw['id']} error=#{e.message} " \
          "own_profile_id=#{@own_profile.id}"
        )
        failed_count += 1
      end

      OwnProfiles::Result.success(data: { synced: synced_count, failed: failed_count })

    rescue Meta::GraphApi::AuthenticationError => e
      OwnProfiles::Result.failure(error: e.message, error_code: :auth_error)
    rescue Meta::GraphApi::RateLimitError => e
      OwnProfiles::Result.failure(error: e.message, error_code: :rate_limit)
    rescue => e
      Rails.logger.error(
        "OwnProfiles::SyncPostsService failed — " \
        "error=#{e.message} own_profile_id=#{@own_profile.id}"
      )
      OwnProfiles::Result.failure(error: e.message, error_code: :unknown)
    end

    private

    def fetch_media(api)
      api.fetch_media(
        fields: 'id,caption,media_type,permalink,timestamp',
        limit: 50
      )
    end

    def sync_single_post(api, raw)
      post_type = MEDIA_TYPE_MAP[raw['media_type']] || 'image'

      ActsAsTenant.with_tenant(@account) do
        own_post = OwnPost.find_or_initialize_by(
          own_profile: @own_profile,
          instagram_post_id: raw['id']
        )

        own_post.assign_attributes(
          account:   @account,
          post_type: post_type,
          caption:   raw['caption'],
          permalink: raw['permalink'],
          posted_at: raw['timestamp']&.then { |t| Time.zone.parse(t) }
        )

        if own_post.new_record? || own_post.metrics.blank?
          metrics = fetch_insights(api, raw['id'], post_type)
          own_post.add_metrics_snapshot(metrics) if metrics.present?
        end

        own_post.save!
        schedule_future_metrics(own_post) if own_post.previously_new_record?
      end
    end

    def fetch_insights(api, media_id, post_type)
      metric_names = case post_type
                     when 'reel'     then Meta::GraphApi::REEL_METRICS
                     when 'carousel' then Meta::GraphApi::CAROUSEL_METRICS
                     when 'story'    then Meta::GraphApi::STORY_METRICS
                     else                 Meta::GraphApi::IMAGE_METRICS
                     end

      api.fetch_post_insights(media_id, metric_names: metric_names)
    rescue => e
      Rails.logger.warn(
        "OwnProfiles::SyncPostsService could not fetch insights — " \
        "media_id=#{media_id} error=#{e.message}"
      )
      {}
    end

    def schedule_future_metrics(own_post)
      base_time = own_post.posted_at || Time.current
      [1, 7, 30].each do |days|
        run_at = base_time + days.days
        next if run_at < Time.current

        OwnPosts::FetchMetricsWorker.perform_at(run_at, own_post.id)
      end
    end
  end
end
