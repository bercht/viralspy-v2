module OwnProfiles
  class Result
    attr_reader :data, :error, :error_code

    def self.success(data: {})
      new(success: true, data: data)
    end

    def self.failure(error:, error_code: nil)
      new(success: false, error: error, error_code: error_code)
    end

    def success? = @success
    def failure? = !@success

    private

    def initialize(success:, data: {}, error: nil, error_code: nil)
      @success    = success
      @data       = data
      @error      = error
      @error_code = error_code
    end
  end
end
