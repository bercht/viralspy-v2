# frozen_string_literal: true

module Transcription
  class Result
    attr_reader :transcript, :duration_seconds, :error, :error_code

    def initialize(success:, transcript: nil, duration_seconds: nil, error: nil, error_code: nil)
      @success = success
      @transcript = transcript
      @duration_seconds = duration_seconds
      @error = error
      @error_code = error_code
    end

    def self.success(transcript:, duration_seconds:)
      new(success: true, transcript: transcript, duration_seconds: duration_seconds)
    end

    def self.failure(error:, error_code:)
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
