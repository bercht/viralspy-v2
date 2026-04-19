module Analyses
  class Result
    attr_reader :data, :error, :error_code

    def initialize(success:, data: nil, error: nil, error_code: nil)
      @success = success
      @data = data || {}
      @error = error
      @error_code = error_code
    end

    def self.success(data: {})
      new(success: true, data: data)
    end

    def self.failure(error:, error_code: nil)
      new(success: false, error: error, error_code: error_code)
    end

    def success?
      @success
    end

    def failure?
      !success?
    end
  end
end
