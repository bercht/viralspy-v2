# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LLM error hierarchy" do
  it "all errors inherit from LLM::Error" do
    [
      LLM::RateLimitError,
      LLM::TimeoutError,
      LLM::AuthenticationError,
      LLM::InvalidRequestError,
      LLM::ModelNotFoundError,
      LLM::ResponseParseError,
      LLM::ProviderNotFoundError,
      LLM::MissingApiKeyError
    ].each do |klass|
      expect(klass.ancestors).to include(LLM::Error), "Expected #{klass} to inherit from LLM::Error"
    end
  end

  it "LLM::Error inherits from StandardError" do
    expect(LLM::Error.ancestors).to include(StandardError)
  end

  it "transient errors inherit from LLM::Error" do
    expect(LLM::RateLimitError.superclass).to eq(LLM::Error)
    expect(LLM::TimeoutError.superclass).to eq(LLM::Error)
  end
end
