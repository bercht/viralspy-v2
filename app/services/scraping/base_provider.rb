module Scraping
  class BaseProvider
    def scrape_profile(handle:, max_posts:)
      raise NotImplementedError, "#{self.class} must implement #scrape_profile"
    end

    protected

    def validate_handle!(handle)
      raise ArgumentError, "handle cannot be blank" if handle.to_s.strip.empty?

      normalized = handle.to_s.strip.sub(/\A@/, "").downcase
      unless normalized.match?(/\A[a-zA-Z0-9_.]{1,30}\z/)
        raise ArgumentError, "invalid instagram handle: #{handle.inspect}"
      end

      normalized
    end
  end
end
