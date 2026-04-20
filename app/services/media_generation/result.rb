module MediaGeneration
  class Result
    attr_reader :error, :error_code, :job_id, :output_url, :status, :duration_seconds

    def initialize(success:, job_id: nil, output_url: nil, status: nil,
                   duration_seconds: nil, error: nil, error_code: nil)
      @success = success
      @job_id = job_id
      @output_url = output_url
      @status = status
      @duration_seconds = duration_seconds
      @error = error
      @error_code = error_code
    end

    def success? = @success
    def failure? = !@success
  end
end
