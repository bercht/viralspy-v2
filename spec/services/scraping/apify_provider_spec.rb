require "rails_helper"

RSpec.describe Scraping::ApifyProvider do
  let(:client) { instance_double(Scraping::Apify::Client) }
  let(:no_sleep) { ->(_) { } }
  let(:provider) { described_class.new(client: client, sleeper: no_sleep) }

  let(:handle) { "curtbercht" }
  let(:max_posts) { 30 }

  describe "happy path" do
    let(:profile_fixture) { JSON.parse(File.read("spec/fixtures/apify/profile_scraper_response.json")) }
    let(:reel_fixture)    { JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_reel.json")) }
    let(:carousel_fixture) { JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_carousel.json")) }
    let(:image_fixture)    { JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_image.json")) }

    before do
      allow(client).to receive(:start_run).with(
        actor_id: "apify~instagram-profile-scraper",
        input: hash_including("usernames" => [ handle ])
      ).and_return({ "id" => "profile_run_1" })

      allow(client).to receive(:get_run).with("profile_run_1")
                                         .and_return({ "status" => "SUCCEEDED" })

      allow(client).to receive(:get_dataset_items).with("profile_run_1")
                                                    .and_return([ profile_fixture ])

      allow(client).to receive(:start_run).with(
        actor_id: "apify~instagram-post-scraper",
        input: hash_including("directUrls" => kind_of(Array))
      ).and_return({ "id" => "posts_run_1" })

      allow(client).to receive(:get_run).with("posts_run_1")
                                         .and_return({ "status" => "SUCCEEDED" })

      allow(client).to receive(:get_dataset_items).with("posts_run_1")
                                                    .and_return([ reel_fixture, carousel_fixture, image_fixture ])
    end

    it "returns success with profile_data and posts" do
      result = provider.scrape_profile(handle: handle, max_posts: max_posts)

      expect(result).to be_success
      expect(result.profile_data[:instagram_handle]).to eq("curtbercht")
      expect(result.profile_data[:followers_count]).to eq(2450)

      expect(result.posts.size).to eq(3)
      expect(result.posts.map { |p| p[:post_type] }).to match_array(%i[reel carousel image])
      expect(result.run_id).to eq("posts_run_1")
    end
  end

  describe "profile-scraper returns empty dataset" do
    before do
      allow(client).to receive(:start_run).and_return({ "id" => "profile_run_empty" })
      allow(client).to receive(:get_run).and_return({ "status" => "SUCCEEDED" })
      allow(client).to receive(:get_dataset_items).with("profile_run_empty").and_return([])
    end

    it "returns failure with :profile_not_found" do
      result = provider.scrape_profile(handle: handle, max_posts: max_posts)
      expect(result).to be_failure
      expect(result.error).to eq(:profile_not_found)
      expect(result.run_id).to eq("profile_run_empty")
    end
  end

  describe "profile has zero recent posts" do
    before do
      allow(client).to receive(:start_run).and_return({ "id" => "profile_run_zero" })
      allow(client).to receive(:get_run).and_return({ "status" => "SUCCEEDED" })
      allow(client).to receive(:get_dataset_items).with("profile_run_zero")
                                                    .and_return([ { "username" => handle, "latestPosts" => [] } ])
    end

    it "returns success with empty posts (does not call post-scraper)" do
      result = provider.scrape_profile(handle: handle, max_posts: max_posts)

      expect(result).to be_success
      expect(result.posts).to eq([])
      expect(client).to have_received(:start_run).once
    end
  end

  describe "post-scraper returns fewer posts than requested" do
    before do
      allow(client).to receive(:start_run)
        .with(actor_id: "apify~instagram-profile-scraper", input: anything)
        .and_return({ "id" => "profile_run" })
      allow(client).to receive(:start_run)
        .with(actor_id: "apify~instagram-post-scraper", input: anything)
        .and_return({ "id" => "posts_run" })

      allow(client).to receive(:get_run).and_return({ "status" => "SUCCEEDED" })

      allow(client).to receive(:get_dataset_items).with("profile_run").and_return([
        JSON.parse(File.read("spec/fixtures/apify/profile_scraper_response.json"))
      ])
      allow(client).to receive(:get_dataset_items).with("posts_run").and_return([
        JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_reel.json")),
        JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_image.json"))
      ])
    end

    it "accepts fewer posts without erroring" do
      result = provider.scrape_profile(handle: handle, max_posts: 30)
      expect(result).to be_success
      expect(result.posts.size).to eq(2)
    end
  end

  describe "profile-scraper raises ProfileNotFoundError" do
    before do
      allow(client).to receive(:start_run).and_raise(Scraping::ProfileNotFoundError, "404 on handle")
    end

    it "returns failure with :profile_not_found" do
      result = provider.scrape_profile(handle: handle, max_posts: max_posts)
      expect(result).to be_failure
      expect(result.error).to eq(:profile_not_found)
    end

    it "does NOT retry on profile_not_found" do
      provider.scrape_profile(handle: handle, max_posts: max_posts)
      expect(client).to have_received(:start_run).once
    end
  end

  describe "profile-scraper run ends with status=FAILED" do
    before do
      allow(client).to receive(:start_run).and_return({ "id" => "profile_run" })
      allow(client).to receive(:get_run).and_return({ "status" => "FAILED" })
    end

    it "returns failure with :run_failed" do
      result = provider.scrape_profile(handle: handle, max_posts: max_posts)
      expect(result).to be_failure
      expect(result.error).to eq(:run_failed)
      expect(result.run_id).to eq("profile_run")
    end
  end

  describe "rate-limited on first attempt, succeeds on retry" do
    let(:profile_fixture) { JSON.parse(File.read("spec/fixtures/apify/profile_scraper_response.json")) }

    it "retries once and succeeds" do
      call_count = 0
      allow(client).to receive(:start_run) do |actor_id:, input:|
        call_count += 1
        if actor_id == "apify~instagram-profile-scraper" && call_count == 1
          raise Scraping::RateLimitError, "429"
        elsif actor_id == "apify~instagram-profile-scraper"
          { "id" => "profile_run" }
        else
          { "id" => "posts_run" }
        end
      end

      allow(client).to receive(:get_run).and_return({ "status" => "SUCCEEDED" })
      allow(client).to receive(:get_dataset_items).with("profile_run").and_return([ profile_fixture ])
      allow(client).to receive(:get_dataset_items).with("posts_run").and_return([])

      result = provider.scrape_profile(handle: handle, max_posts: max_posts)
      expect(result).to be_success
    end
  end

  describe "rate-limited on both attempts" do
    before do
      allow(client).to receive(:start_run).and_raise(Scraping::RateLimitError, "429 persistent")
    end

    it "returns failure with :rate_limited after 2 attempts" do
      result = provider.scrape_profile(handle: handle, max_posts: max_posts)
      expect(result).to be_failure
      expect(result.error).to eq(:rate_limited)
      expect(client).to have_received(:start_run).twice
    end
  end

  describe "timeout retry behavior" do
    before do
      allow(client).to receive(:start_run).and_raise(Scraping::TimeoutError, "timeout")
    end

    it "retries once then returns :timeout" do
      result = provider.scrape_profile(handle: handle, max_posts: max_posts)
      expect(result.error).to eq(:timeout)
      expect(client).to have_received(:start_run).twice
    end
  end

  describe "handle validation" do
    it "normalizes handle (strip, remove leading @, lowercase)" do
      allow(client).to receive(:start_run).and_return({ "id" => "r" })
      allow(client).to receive(:get_run).and_return({ "status" => "SUCCEEDED" })
      allow(client).to receive(:get_dataset_items).and_return([ { "username" => "ok" } ], [])

      provider.scrape_profile(handle: "  @CurtBercht  ", max_posts: 10)

      expect(client).to have_received(:start_run)
        .with(actor_id: "apify~instagram-profile-scraper",
              input: hash_including("usernames" => [ "curtbercht" ]))
    end

    it "raises ArgumentError on invalid handle" do
      expect { provider.scrape_profile(handle: "foo bar", max_posts: 10) }
        .to raise_error(ArgumentError, /invalid instagram handle/)
    end
  end
end
