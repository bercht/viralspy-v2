# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transcription error hierarchy" do
  it "all errors inherit from Transcription::Error" do
    [
      Transcription::RateLimitError,
      Transcription::TimeoutError,
      Transcription::FileTooLargeError,
      Transcription::DownloadError,
      Transcription::AuthenticationError,
      Transcription::ResponseParseError,
      Transcription::ProviderNotFoundError,
      Transcription::MissingApiKeyError
    ].each do |klass|
      expect(klass.ancestors).to include(Transcription::Error), "Expected #{klass} to inherit from Transcription::Error"
    end
  end

  it "Transcription::Error inherits from StandardError" do
    expect(Transcription::Error.ancestors).to include(StandardError)
  end
end
