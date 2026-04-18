require "rails_helper"

RSpec.describe Scraping::Factory do
  describe ".build" do
    around do |example|
      original_provider = ENV["SCRAPING_PROVIDER"]
      original_token = ENV["APIFY_API_TOKEN"]
      ENV.delete("SCRAPING_PROVIDER")
      ENV["APIFY_API_TOKEN"] = "test_token_for_factory_spec"
      example.run
    ensure
      ENV["SCRAPING_PROVIDER"] = original_provider
      ENV["APIFY_API_TOKEN"] = original_token
    end

    it "returns ApifyProvider by default" do
      expect(described_class.build).to be_a(Scraping::ApifyProvider)
    end

    it "returns ApifyProvider when explicitly 'apify'" do
      expect(described_class.build(provider: "apify")).to be_a(Scraping::ApifyProvider)
    end

    it "is case-insensitive" do
      expect(described_class.build(provider: "APIFY")).to be_a(Scraping::ApifyProvider)
    end

    it "raises UnknownProviderError on unknown provider" do
      expect { described_class.build(provider: "weirdscraper") }
        .to raise_error(Scraping::Factory::UnknownProviderError, /weirdscraper/)
    end

    it "reads from ENV when no argument given" do
      ENV["SCRAPING_PROVIDER"] = "apify"
      expect(described_class.build).to be_a(Scraping::ApifyProvider)
    end
  end
end
