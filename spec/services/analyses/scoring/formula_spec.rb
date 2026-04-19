require "rails_helper"

RSpec.describe Analyses::Scoring::Formula do
  let(:account) { create(:account) }
  let(:competitor) do
    ActsAsTenant.with_tenant(account) { create(:competitor, account: account) }
  end
  let(:analysis) do
    ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) }
  end

  def build_post(attrs = {})
    ActsAsTenant.with_tenant(account) do
      defaults = {
        account:          account,
        competitor:       competitor,
        analysis:         analysis,
        instagram_post_id: SecureRandom.hex(4),
        post_type:        :reel,
        likes_count:      100,
        comments_count:   20,
        posted_at:        2.days.ago
      }
      build(:post, defaults.merge(attrs))
    end
  end

  describe ".calculate" do
    context "with a normal eligible post" do
      it "returns a positive score" do
        post = build_post(likes_count: 500, comments_count: 50, posted_at: 2.days.ago)

        score = described_class.calculate(post: post, followers: 10_000)

        expect(score).to be > 0
      end

      it "comments weigh 3x more than likes" do
        fixed_time = 2.days.ago
        post_more_comments = build_post(likes_count: 100, comments_count: 100, posted_at: fixed_time)
        post_more_likes    = build_post(likes_count: 400, comments_count: 0,   posted_at: fixed_time)

        score_comments = described_class.calculate(post: post_more_comments, followers: 10_000)
        score_likes    = described_class.calculate(post: post_more_likes,    followers: 10_000)

        # post_more_comments: 100 + 100*3 = 400 engagement
        # post_more_likes: 400 + 0*3 = 400 engagement — should be equal
        expect(score_comments).to eq(score_likes)
      end

      it "returns higher score for more engagement at same age" do
        high_engagement = build_post(likes_count: 1_000, comments_count: 100, posted_at: 3.days.ago)
        low_engagement  = build_post(likes_count: 100,   comments_count: 10,  posted_at: 3.days.ago)

        high_score = described_class.calculate(post: high_engagement, followers: 10_000)
        low_score  = described_class.calculate(post: low_engagement,  followers: 10_000)

        expect(high_score).to be > low_score
      end

      it "returns higher score for newer post (maturity boost)" do
        newer = build_post(likes_count: 500, comments_count: 50, posted_at: 1.day.ago)
        older = build_post(likes_count: 500, comments_count: 50, posted_at: 6.days.ago)

        newer_score = described_class.calculate(post: newer, followers: 10_000)
        older_score = described_class.calculate(post: older, followers: 10_000)

        expect(newer_score).to be > older_score
      end

      it "caps maturity_boost at 1.0 for posts older than 7 days" do
        week_old   = build_post(likes_count: 500, comments_count: 50, posted_at: 7.days.ago)
        month_old  = build_post(likes_count: 500, comments_count: 50, posted_at: 30.days.ago)

        week_score  = described_class.calculate(post: week_old,  followers: 10_000)
        month_score = described_class.calculate(post: month_old, followers: 10_000)

        expect(week_score).to eq(month_score)
      end
    end

    context "ineligibility" do
      it "returns 0.0 for posts with fewer than 10 interactions" do
        post = build_post(likes_count: 5, comments_count: 3, posted_at: 2.days.ago)

        expect(described_class.calculate(post: post, followers: 10_000)).to eq(0.0)
      end

      it "returns 0.0 for posts newer than 6 hours" do
        post = build_post(likes_count: 500, comments_count: 50, posted_at: 1.hour.ago)

        expect(described_class.calculate(post: post, followers: 10_000)).to eq(0.0)
      end

      it "returns 0.0 for posts without posted_at" do
        post = build_post(likes_count: 500, comments_count: 50, posted_at: nil)

        expect(described_class.calculate(post: post, followers: 10_000)).to eq(0.0)
      end

      it "returns 0.0 when followers is 0" do
        post = build_post(likes_count: 500, comments_count: 50, posted_at: 2.days.ago)

        expect(described_class.calculate(post: post, followers: 0)).to eq(0.0)
      end

      it "returns 0.0 when followers is negative" do
        post = build_post(likes_count: 500, comments_count: 50, posted_at: 2.days.ago)

        expect(described_class.calculate(post: post, followers: -100)).to eq(0.0)
      end
    end

    context ".eligible?" do
      it "returns true for a post with >= 10 interactions and >= 6 hours old" do
        post = build_post(likes_count: 8, comments_count: 3, posted_at: 12.hours.ago)

        expect(described_class.eligible?(post)).to be(true)
      end

      it "returns false for post with < 10 interactions" do
        post = build_post(likes_count: 5, comments_count: 4, posted_at: 12.hours.ago)

        expect(described_class.eligible?(post)).to be(false)
      end

      it "returns false for post younger than 6 hours" do
        post = build_post(likes_count: 100, comments_count: 20, posted_at: 5.hours.ago)

        expect(described_class.eligible?(post)).to be(false)
      end

      it "returns false for post with nil posted_at" do
        post = build_post(likes_count: 100, comments_count: 20, posted_at: nil)

        expect(described_class.eligible?(post)).to be(false)
      end
    end
  end
end
