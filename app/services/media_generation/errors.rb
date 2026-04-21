module MediaGeneration
  module Errors
    class Base < StandardError; end
    class InvalidApiKey < Base; end
    class RateLimitExceeded < Base; end
    class AvatarNotFound < Base; end
    class VoiceNotFound < Base; end
    class GenerationFailed < Base; end
    class Timeout < Base; end
    class ParseError < Base; end
  end
end
