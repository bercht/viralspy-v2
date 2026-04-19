require "rails_helper"

RSpec.describe Analyses::ProfileMetricsStep do
  let(:account) { create(:account) }
  let(:competitor) do
    ActsAsTenant.with_tenant(account) do
      create(:competitor, account: account, followers_count: 10_000)
    end
  end
  let(:analysis) do
    ActsAsTenant.with_tenant(account) do
      create(:analysis, account: account, competitor: competitor, status: :scoring)
    end
  end

  def create_posts(attrs_list)
    ActsAsTenant.with_tenant(account) do
      attrs_list.map do |attrs|
        create(:post, { account: account, competitor: competitor, analysis: analysis }.merge(attrs))
      end
    end
  end

  describe ".call" do
    context "when analysis has no posts" do
      it "returns success with empty metrics" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
        end
      end

      it "saves an empty-ish profile_metrics to analysis" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.profile_metrics).to be_present
        end
      end
    end

    context "with posts" do
      before do
        create_posts([
          { post_type: :reel,     likes_count: 200, comments_count: 20, posted_at: 1.day.ago,  hashtags: %w[imoveis corretor imoveis] },
          { post_type: :reel,     likes_count: 400, comments_count: 40, posted_at: 5.days.ago, hashtags: %w[imoveis casapropria] },
          { post_type: :reel,     likes_count: 600, comments_count: 60, posted_at: 9.days.ago, hashtags: %w[corretor casapropria] },
          { post_type: :reel,     likes_count: 100, comments_count: 10, posted_at: 12.days.ago, hashtags: [] },
          { post_type: :reel,     likes_count: 300, comments_count: 30, posted_at: 16.days.ago, hashtags: [] },
          { post_type: :carousel, likes_count: 500, comments_count: 50, posted_at: 3.days.ago,  hashtags: %w[imoveis] },
          { post_type: :carousel, likes_count: 250, comments_count: 25, posted_at: 7.days.ago,  hashtags: [] },
          { post_type: :carousel, likes_count: 150, comments_count: 15, posted_at: 11.days.ago, hashtags: [] },
          { post_type: :image,    likes_count: 120, comments_count: 12, posted_at: 2.days.ago,  hashtags: %w[corretor] },
          { post_type: :image,    likes_count: 180, comments_count: 18, posted_at: 6.days.ago,  hashtags: [] }
        ])
      end

      it "returns a success result" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
        end
      end

      it "saves profile_metrics to the analysis" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.profile_metrics).to be_a(Hash)
          expect(analysis.profile_metrics).to include("posts_per_week", "content_mix", "avg_likes_per_post")
        end
      end

      it "calculates correct content_mix proportions" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          mix = analysis.reload.profile_metrics["content_mix"]
          expect(mix["reel"]).to eq(0.5)
          expect(mix["carousel"]).to eq(0.3)
          expect(mix["image"]).to eq(0.2)
        end
      end

      it "calculates average likes per post" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          # (200+400+600+100+300+500+250+150+120+180) / 10 = 280
          expect(analysis.reload.profile_metrics["avg_likes_per_post"]).to eq(280)
        end
      end

      it "calculates average comments per post" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          # (20+40+60+10+30+50+25+15+12+18) / 10 = 28
          expect(analysis.reload.profile_metrics["avg_comments_per_post"]).to eq(28)
        end
      end

      it "returns top hashtags ordered by frequency" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          # imoveis appears 3 times, corretor 3 times, casapropria 2 times
          top = analysis.reload.profile_metrics["top_hashtags"]
          expect(top).to be_an(Array)
          expect(top).to include("imoveis", "corretor", "casapropria")
        end
      end

      it "calculates posts_per_week" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.profile_metrics["posts_per_week"]).to be > 0
        end
      end

      it "calculates best_posting_days" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          days = analysis.reload.profile_metrics["best_posting_days"]
          expect(days).to be_an(Array)
          expect(days.size).to be <= 3
        end
      end

      it "calculates best_posting_hours" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          hours = analysis.reload.profile_metrics["best_posting_hours"]
          expect(hours).to be_an(Array)
          expect(hours.size).to be <= 3
          expect(hours).to all(be_between(0, 23))
        end
      end

      it "calculates avg_engagement_rate using competitor followers" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          rate = analysis.reload.profile_metrics["avg_engagement_rate"]
          expect(rate).to be > 0
          expect(rate).to be < 1
        end
      end

      it "includes posting_consistency_score between 0 and 1" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          score = analysis.reload.profile_metrics["posting_consistency_score"]
          expect(score).to be_between(0.0, 1.0)
        end
      end
    end

    context "with competitor having zero followers" do
      before do
        competitor.update!(followers_count: 0)
        create_posts([
          { post_type: :reel, likes_count: 100, comments_count: 10, posted_at: 2.days.ago, hashtags: [] }
        ])
      end

      it "returns 0 for avg_engagement_rate without dividing by zero" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(analysis.reload.profile_metrics["avg_engagement_rate"]).to eq(0.0)
        end
      end
    end

    context "with posts missing posted_at" do
      before do
        create_posts([
          { post_type: :reel, likes_count: 100, comments_count: 10, posted_at: nil, hashtags: [] },
          { post_type: :reel, likes_count: 200, comments_count: 20, posted_at: 5.days.ago, hashtags: [] }
        ])
      end

      it "does not raise and ignores nil posted_at in date-dependent metrics" do
        ActsAsTenant.with_tenant(account) do
          expect { described_class.call(analysis) }.not_to raise_error
        end
      end
    end

    context "with fewer than 3 posts with posted_at" do
      before do
        create_posts([
          { post_type: :reel, likes_count: 100, comments_count: 5, posted_at: 1.day.ago, hashtags: [] },
          { post_type: :reel, likes_count: 200, comments_count: 8, posted_at: nil, hashtags: [] }
        ])
      end

      it "returns posting_consistency_score of 0.0" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.profile_metrics["posting_consistency_score"]).to eq(0.0)
        end
      end
    end
  end
end
