module Scraping
  class Factory
    class UnknownProviderError < Scraping::Error; end

    def self.build(provider: ENV.fetch("SCRAPING_PROVIDER", "apify"))
      case provider.to_s.downcase
      when "apify"
        Scraping::ApifyProvider.new
      else
        raise UnknownProviderError, "unknown scraping provider: #{provider.inspect}"
      end
    end
  end
end
