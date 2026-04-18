module Scraping
  module Apify
    module Parser
      module_function

      def parse_profile(raw)
        return {} if raw.nil?

        {
          instagram_handle: raw["username"].to_s.downcase,
          full_name:         raw["fullName"],
          bio:               raw["biography"],
          followers_count:   safe_int(raw["followersCount"]),
          following_count:   safe_int(raw["followsCount"]),
          posts_count:       safe_int(raw["postsCount"]),
          profile_pic_url:   raw["profilePicUrl"] || raw["profilePicUrlHD"],
          recent_post_urls:  Array(raw["latestPosts"]).map { |p| p["url"] }.compact
        }
      end

      def parse_posts(raw)
        Array(raw).filter_map { |item| parse_post(item) }
      end

      def parse_post(raw)
        return nil if raw.blank?

        type = detect_type(raw)
        return nil unless type

        {
          post_type:              type,
          instagram_post_id:      raw["id"].to_s,
          shortcode:              raw["shortCode"],
          caption:                raw["caption"],
          display_url:            raw["displayUrl"],
          video_url:              (type == :reel ? raw["videoUrl"] : nil),
          likes_count:            safe_int(raw["likesCount"]),
          comments_count:         safe_int(raw["commentsCount"]),
          video_view_count:       safe_int(raw["videoViewCount"]),
          video_duration_seconds: safe_float(raw["videoDuration"]),
          hashtags:               Array(raw["hashtags"]).map(&:to_s),
          mentions:               Array(raw["mentions"]).map(&:to_s),
          posted_at:              parse_timestamp(raw["timestamp"]),
          owner_username:         raw["ownerUsername"]&.downcase,
          url:                    raw["url"]
        }
      end

      def detect_type(raw)
        case raw["type"]
        when "Video"
          raw["productType"] == "clips" ? :reel : nil
        when "Sidecar"
          :carousel
        when "GraphImage", "Image"
          :image
        end
      end

      def safe_int(val)
        return nil if val.nil?
        Integer(val)
      rescue ArgumentError, TypeError
        nil
      end

      def safe_float(val)
        return nil if val.nil?
        Float(val)
      rescue ArgumentError, TypeError
        nil
      end

      def parse_timestamp(val)
        return nil if val.blank?
        Time.zone.parse(val.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
