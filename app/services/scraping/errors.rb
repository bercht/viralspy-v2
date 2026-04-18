module Scraping
  class Error < StandardError; end
  class RateLimitError < Error; end
  class ProfileNotFoundError < Error; end
  class TimeoutError < Error; end
  class RunFailedError < Error; end
  class ParseError < Error; end
  class EmptyDatasetError < Error; end
end
