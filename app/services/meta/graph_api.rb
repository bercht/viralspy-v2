module Meta
  class GraphApi
    BASE_URL = "https://graph.instagram.com/v21.0".freeze

    class AuthenticationError < StandardError; end
    class RateLimitError < StandardError; end
    class ApiError < StandardError
      attr_reader :code

      def initialize(msg, code: nil)
        super(msg)
        @code = code
      end
    end

    REEL_METRICS     = %w[plays reach impressions saved shares likes comments].freeze
    CAROUSEL_METRICS = %w[reach impressions saved shares likes comments].freeze
    IMAGE_METRICS    = %w[reach impressions saved shares likes comments].freeze
    STORY_METRICS    = %w[reach impressions exits replies taps_forward taps_back].freeze

    def initialize(access_token:)
      @access_token = access_token
    end

    def fetch_media(fields: nil, limit: 25)
      default_fields = "id,caption,media_type,permalink,timestamp"
      response = get("/me/media", {
        fields: fields || default_fields,
        limit: limit
      })
      response["data"] || []
    end

    def fetch_post_insights(media_id, metric_names:)
      response = get("/#{media_id}/insights", {
        metric: metric_names.join(",")
      })
      parse_insights(response["data"] || [])
    end

    def fetch_profile(fields: "id,username,name,biography,followers_count,media_count")
      get("/me", { fields: fields })
    end

    private

    def get(path, params = {})
      response = HTTParty.get(
        "#{BASE_URL}#{path}",
        query: params.merge(access_token: @access_token),
        timeout: 15
      )
      handle_response(response)
    end

    def handle_response(response)
      body = response.parsed_response

      raise AuthenticationError, "Token inválido ou expirado (401)" if response.code == 401
      raise RateLimitError, "Rate limit atingido (429)" if response.code == 429

      if body.is_a?(Hash) && body["error"].present?
        error = body["error"]
        raise ApiError.new(
          error["message"] || "Erro desconhecido da Graph API",
          code: error["code"]
        )
      end

      unless response.success?
        raise ApiError.new("HTTP #{response.code}: #{body}", code: response.code)
      end

      body
    end

    def parse_insights(data)
      data.each_with_object({}) do |item, hash|
        name   = item["name"]
        values = item["values"]
        value  = values&.first&.dig("value") || values&.first
        hash[name] = value
      end
    end
  end
end
