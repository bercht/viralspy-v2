module Scraping
  class Result
    attr_reader :posts, :profile_data, :error, :message, :run_id

    def self.success(posts:, profile_data:, run_id: nil)
      new(success: true, posts: posts, profile_data: profile_data, run_id: run_id)
    end

    def self.failure(error:, message: nil, run_id: nil)
      new(success: false, error: error, message: message, run_id: run_id)
    end

    def initialize(success:, posts: [], profile_data: {}, error: nil, message: nil, run_id: nil)
      @success = success
      @posts = posts
      @profile_data = profile_data
      @error = error
      @message = message
      @run_id = run_id
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end
end
