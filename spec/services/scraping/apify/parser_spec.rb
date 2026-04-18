require "rails_helper"

RSpec.describe Scraping::Apify::Parser do
  describe ".parse_profile" do
    it "maps profile-scraper response to internal format" do
      raw = JSON.parse(File.read("spec/fixtures/apify/profile_scraper_response.json"))

      profile = described_class.parse_profile(raw)

      expect(profile[:instagram_handle]).to eq("curtbercht")
      expect(profile[:full_name]).to eq("Curt B Neto")
      expect(profile[:bio]).to start_with("Marketing imobiliário")
      expect(profile[:followers_count]).to eq(2450)
      expect(profile[:following_count]).to eq(312)
      expect(profile[:posts_count]).to eq(187)
      expect(profile[:profile_pic_url]).to include("cdninstagram")
      expect(profile[:recent_post_urls]).to eq([
        "https://www.instagram.com/p/DPkgs2uDDjg/",
        "https://www.instagram.com/p/DWml4P7CU4o/"
      ])
    end

    it "returns empty hash on nil input" do
      expect(described_class.parse_profile(nil)).to eq({})
    end

    it "returns parsed hash on empty hash input" do
      profile = described_class.parse_profile({})
      expect(profile[:instagram_handle]).to eq("")
      expect(profile[:followers_count]).to be_nil
      expect(profile[:recent_post_urls]).to eq([])
    end

    it "downcases the handle" do
      profile = described_class.parse_profile({ "username" => "CurtBercht" })
      expect(profile[:instagram_handle]).to eq("curtbercht")
    end

    it "falls back to profilePicUrlHD when profilePicUrl is missing" do
      profile = described_class.parse_profile({ "profilePicUrlHD" => "https://hd.jpg" })
      expect(profile[:profile_pic_url]).to eq("https://hd.jpg")
    end
  end

  describe ".parse_posts" do
    it "maps a reel (type=Video productType=clips)" do
      raw = JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_reel.json"))
      post = described_class.parse_posts([ raw ]).first

      expect(post[:post_type]).to eq(:reel)
      expect(post[:instagram_post_id]).to eq("3739257410524297440")
      expect(post[:shortcode]).to eq("DPkgs2uDDjg")
      expect(post[:video_url]).to include("video.mp4")
      expect(post[:video_duration_seconds]).to eq(24.2)
      expect(post[:video_view_count]).to eq(258)
      expect(post[:likes_count]).to eq(19)
      expect(post[:comments_count]).to eq(6)
      expect(post[:hashtags]).to eq(%w[ia instagram])
      expect(post[:posted_at]).to be_a(ActiveSupport::TimeWithZone)
      expect(post[:owner_username]).to eq("curtbercht")
    end

    it "maps a carousel (type=Sidecar) without video_url" do
      raw = JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_carousel.json"))
      post = described_class.parse_posts([ raw ]).first

      expect(post[:post_type]).to eq(:carousel)
      expect(post[:video_url]).to be_nil
      expect(post[:display_url]).to include("d1.jpg")
      expect(post[:likes_count]).to eq(2)
    end

    it "maps an image (type=GraphImage)" do
      raw = JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_image.json"))
      post = described_class.parse_posts([ raw ]).first

      expect(post[:post_type]).to eq(:image)
      expect(post[:video_url]).to be_nil
      expect(post[:video_duration_seconds]).to be_nil
    end

    it "filters out unknown types (IGTV, stories, lives)" do
      raw = JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_unknown.json"))
      expect(described_class.parse_posts([ raw ])).to eq([])
    end

    it "filters out Video items that are NOT clips (e.g. legacy IGTV)" do
      raw = {
        "id" => "x",
        "type" => "Video",
        "productType" => "feed",
        "shortCode" => "OLD"
      }
      expect(described_class.parse_posts([ raw ])).to eq([])
    end

    it "parses arrays: multiple posts of different types in same payload" do
      reel = JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_reel.json"))
      carousel = JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_carousel.json"))
      image = JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_image.json"))
      unknown = JSON.parse(File.read("spec/fixtures/apify/post_scraper_response_unknown.json"))

      posts = described_class.parse_posts([ reel, carousel, image, unknown ])

      expect(posts.map { |p| p[:post_type] }).to eq(%i[reel carousel image])
    end

    it "returns [] on blank input" do
      expect(described_class.parse_posts(nil)).to eq([])
      expect(described_class.parse_posts([])).to eq([])
    end

    it "is robust against malformed values" do
      raw = {
        "id" => 123,
        "type" => "Sidecar",
        "likesCount" => "not a number",
        "videoDuration" => "not a float",
        "timestamp" => "garbage",
        "hashtags" => nil,
        "mentions" => nil
      }
      post = described_class.parse_posts([ raw ]).first

      expect(post[:post_type]).to eq(:carousel)
      expect(post[:instagram_post_id]).to eq("123")
      expect(post[:likes_count]).to be_nil
      expect(post[:video_duration_seconds]).to be_nil
      expect(post[:posted_at]).to be_nil
      expect(post[:hashtags]).to eq([])
      expect(post[:mentions]).to eq([])
    end

    it "does not prefix hashtags with #" do
      raw = { "type" => "Sidecar", "hashtags" => %w[imoveis corretor casa], "id" => "x" }
      post = described_class.parse_posts([ raw ]).first
      expect(post[:hashtags]).to eq(%w[imoveis corretor casa])
      expect(post[:hashtags].none? { |h| h.start_with?("#") }).to be true
    end
  end
end
