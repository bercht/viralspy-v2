require "rails_helper"

RSpec.describe Analyses::ScrapeStep do
  let(:account) { create(:account) }
  let(:competitor) do
    ActsAsTenant.with_tenant(account) do
      create(:competitor, account: account, instagram_handle: "testhandle", followers_count: 10_000)
    end
  end
  let(:analysis) do
    ActsAsTenant.with_tenant(account) do
      create(:analysis, account: account, competitor: competitor, status: :pending)
    end
  end

  let(:profile_data) do
    {
      instagram_handle: "testhandle",
      full_name: "Test User",
      bio: "A great bio",
      followers_count: 12_000,
      following_count: 500,
      posts_count: 120,
      profile_pic_url: "https://example.com/pic.jpg",
      recent_post_urls: []
    }
  end

  let(:posts_data) do
    [
      {
        instagram_post_id: "ABC123",
        shortcode: "ABC123",
        post_type: :reel,
        caption: "Post 1 caption",
        display_url: "https://example.com/1.jpg",
        video_url: "https://example.com/1.mp4",
        likes_count: 500,
        comments_count: 30,
        video_view_count: 2_000,
        video_duration_seconds: 15.0,
        hashtags: %w[imoveis corretor],
        mentions: [],
        posted_at: 2.days.ago,
        owner_username: "testhandle",
        url: "https://instagram.com/p/ABC123"
      },
      {
        instagram_post_id: "DEF456",
        shortcode: "DEF456",
        post_type: :carousel,
        caption: "Post 2 caption",
        display_url: "https://example.com/2.jpg",
        video_url: nil,
        likes_count: 300,
        comments_count: 15,
        video_view_count: nil,
        video_duration_seconds: nil,
        hashtags: [],
        mentions: [],
        posted_at: 5.days.ago,
        owner_username: "testhandle",
        url: "https://instagram.com/p/DEF456"
      }
    ]
  end

  let(:scraping_success) do
    Scraping::Result.success(posts: posts_data, profile_data: profile_data)
  end

  let(:mock_provider) { instance_double(Scraping::ApifyProvider) }

  before do
    allow(Scraping::Factory).to receive(:build).and_return(mock_provider)
  end

  describe ".call" do
    context "happy path" do
      before do
        allow(mock_provider).to receive(:scrape_profile).and_return(scraping_success)
      end

      it "returns a success result" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
        end
      end

      it "persists posts to the database" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.posts.count).to eq(2)
        end
      end

      it "advances analysis status to scoring" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.status).to eq("scoring")
        end
      end

      it "updates posts_scraped_count" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.posts_scraped_count).to eq(2)
        end
      end

      it "sets scraping_provider from ENV" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.scraping_provider).to be_present
        end
      end

      it "updates competitor with profile metadata" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          competitor.reload
          expect(competitor.full_name).to eq("Test User")
          expect(competitor.followers_count).to eq(12_000)
          expect(competitor.bio).to eq("A great bio")
          expect(competitor.last_scraped_at).to be_present
        end
      end

      it "assigns correct account to all persisted posts" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.posts.pluck(:account_id)).to all(eq(account.id))
        end
      end

      it "calls scrape_profile with competitor handle and analysis.max_posts" do
        ActsAsTenant.with_tenant(account) do
          expect(mock_provider).to receive(:scrape_profile).with(
            handle: "testhandle",
            max_posts: analysis.max_posts
          ).and_return(scraping_success)

          described_class.call(analysis)
        end
      end
    end

    context "when scraping returns failure" do
      let(:scraping_failure) do
        Scraping::Result.failure(error: :profile_not_found, message: "Profile not found")
      end

      before do
        allow(mock_provider).to receive(:scrape_profile).and_return(scraping_failure)
      end

      it "returns a failure result" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:scraping_failed)
        end
      end

      it "marks analysis as failed" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.status).to eq("failed")
        end
      end

      it "sets error_message on analysis" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.error_message).to be_present
        end
      end

      it "sets finished_at on analysis" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.finished_at).to be_present
        end
      end
    end

    context "when scraping raises an exception" do
      before do
        allow(mock_provider).to receive(:scrape_profile).and_raise(StandardError, "Unexpected boom")
      end

      it "returns a failure result with scrape_exception code" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:scrape_exception)
        end
      end

      it "marks analysis as failed" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.status).to eq("failed")
        end
      end
    end

    context "when a single post has invalid data" do
      let(:posts_with_invalid) do
        [
          posts_data.first,
          { instagram_post_id: nil, post_type: :reel, likes_count: 0, comments_count: 0 }
        ]
      end
      let(:partial_success) do
        Scraping::Result.success(posts: posts_with_invalid, profile_data: profile_data)
      end

      before do
        allow(mock_provider).to receive(:scrape_profile).and_return(partial_success)
      end

      it "skips invalid posts but persists valid ones" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(analysis.posts.count).to eq(1)
        end
      end
    end
  end
end
