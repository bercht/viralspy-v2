# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiCredentials errors" do
  it "defines Error as base StandardError" do
    expect(ApiCredentials::Error.ancestors).to include(StandardError)
  end

  it "defines AuthenticationError, QuotaExceededError, UnknownError" do
    expect(ApiCredentials::AuthenticationError.ancestors).to include(ApiCredentials::Error)
    expect(ApiCredentials::QuotaExceededError.ancestors).to include(ApiCredentials::Error)
    expect(ApiCredentials::UnknownError.ancestors).to include(ApiCredentials::Error)
  end

  describe "NotConfiguredError" do
    it "exposes provider and use_case" do
      err = ApiCredentials::NotConfiguredError.new(provider: "openai", use_case: "analysis")
      expect(err.provider).to eq("openai")
      expect(err.use_case).to eq("analysis")
    end

    it "builds a helpful message when use_case present" do
      err = ApiCredentials::NotConfiguredError.new(provider: "openai", use_case: "analysis")
      expect(err.message).to include("openai")
      expect(err.message).to include("analysis")
      expect(err.message).to include("Settings → API Keys")
    end

    it "builds a message without use_case when omitted" do
      err = ApiCredentials::NotConfiguredError.new(provider: "anthropic")
      expect(err.message).to include("anthropic")
      expect(err.message).not_to match(/use.?case/i)
    end
  end
end
