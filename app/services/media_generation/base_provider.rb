module MediaGeneration
  class BaseProvider
    def initialize(api_key:)
      @api_key = api_key
    end

    def start_generation(script:, avatar_id:, voice_id:, title:)
      raise NotImplementedError, "#{self.class} must implement #start_generation"
    end

    def check_status(job_id:)
      raise NotImplementedError, "#{self.class} must implement #check_status"
    end

    def validate_api_key
      raise NotImplementedError, "#{self.class} must implement #validate_api_key"
    end

    private

    attr_reader :api_key
  end
end
