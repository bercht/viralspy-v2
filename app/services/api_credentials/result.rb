# frozen_string_literal: true

module ApiCredentials
  class Result
    attr_reader :status, :message

    def self.success(message: "API key validated successfully")
      new(status: :verified, message: message)
    end

    def self.failure(status:, message:)
      new(status: status, message: message)
    end

    def initialize(status:, message:)
      @status = status
      @message = message
    end

    def success?
      status == :verified
    end

    def failure?
      !success?
    end
  end
end
