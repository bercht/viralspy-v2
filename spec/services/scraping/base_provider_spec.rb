require "rails_helper"

RSpec.describe Scraping::BaseProvider do
  describe "#scrape_profile" do
    it "raises NotImplementedError" do
      expect { described_class.new.scrape_profile(handle: "foo", max_posts: 10) }
        .to raise_error(NotImplementedError, /must implement/)
    end
  end

  describe "#validate_handle! (via test double)" do
    let(:provider) do
      Class.new(described_class) do
        def scrape_profile(handle:, max_posts:)
          validate_handle!(handle)
        end
      end.new
    end

    it "accepts valid handles and returns normalized" do
      expect(provider.scrape_profile(handle: "  @FooBar  ", max_posts: 5)).to eq("foobar")
      expect(provider.scrape_profile(handle: "user.name_123", max_posts: 5)).to eq("user.name_123")
    end

    it "raises ArgumentError on blank handle" do
      expect { provider.scrape_profile(handle: "", max_posts: 5) }.to raise_error(ArgumentError, /blank/)
      expect { provider.scrape_profile(handle: "   ", max_posts: 5) }.to raise_error(ArgumentError, /blank/)
    end

    it "raises ArgumentError on malformed handle" do
      [ "foo bar", "foo/bar", "foo@bar", "a\\b", "#hashtag" ].each do |bad|
        expect { provider.scrape_profile(handle: bad, max_posts: 5) }
          .to raise_error(ArgumentError, /invalid instagram handle/)
      end

      too_long = "a" * 31
      expect { provider.scrape_profile(handle: too_long, max_posts: 5) }
        .to raise_error(ArgumentError, /invalid instagram handle/)
    end
  end
end
