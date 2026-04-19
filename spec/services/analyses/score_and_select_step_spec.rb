require "rails_helper"

RSpec.describe Analyses::ScoreAndSelectStep do
  let(:account) { create(:account) }
  let(:competitor) do
    ActsAsTenant.with_tenant(account) do
      create(:competitor, account: account, followers_count: 10_000)
    end
  end
  let(:analysis) do
    ActsAsTenant.with_tenant(account) do
      create(:analysis, account: account, competitor: competitor, status: :scoring, max_posts: 30)
    end
  end

  def create_eligible_posts(count:, type:, base_likes: 200)
    ActsAsTenant.with_tenant(account) do
      count.times.map do |i|
        create(:post,
          account: account, competitor: competitor, analysis: analysis,
          post_type: type, likes_count: base_likes + (i * 10), comments_count: 20,
          posted_at: (i + 1).days.ago)
      end
    end
  end

  def create_ineligible_post(type: :reel)
    ActsAsTenant.with_tenant(account) do
      create(:post,
        account: account, competitor: competitor, analysis: analysis,
        post_type: type, likes_count: 1, comments_count: 0, posted_at: 2.days.ago)
    end
  end

  describe ".call" do
    context "with enough posts of each type" do
      before do
        create_eligible_posts(count: 15, type: :reel)
        create_eligible_posts(count: 7,  type: :carousel)
        create_eligible_posts(count: 5,  type: :image)
      end

      it "returns a success result" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
        end
      end

      it "selects exactly 12 reels" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.posts.where(post_type: :reel, selected_for_analysis: true).count).to eq(12)
        end
      end

      it "selects exactly 5 carousels" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.posts.where(post_type: :carousel, selected_for_analysis: true).count).to eq(5)
        end
      end

      it "selects exactly 3 images" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.posts.where(post_type: :image, selected_for_analysis: true).count).to eq(3)
        end
      end

      it "advances analysis status to transcribing" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.status).to eq("transcribing")
        end
      end

      it "sets posts_analyzed_count to total selected" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.posts_analyzed_count).to eq(20)
        end
      end
    end

    context "with fewer posts than limits" do
      before do
        create_eligible_posts(count: 8, type: :reel)
        create_eligible_posts(count: 3, type: :carousel)
        create_eligible_posts(count: 1, type: :image)
      end

      it "selects all available reels when fewer than limit" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.posts.where(post_type: :reel, selected_for_analysis: true).count).to eq(8)
        end
      end

      it "sets posts_analyzed_count to actual selected count" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.posts_analyzed_count).to eq(12)
        end
      end
    end

    context "with no posts for a type" do
      before do
        create_eligible_posts(count: 5, type: :reel)
      end

      it "returns success even when some types have zero posts" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
        end
      end

      it "selects 0 for missing types" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.posts.where(post_type: :carousel, selected_for_analysis: true).count).to eq(0)
          expect(analysis.posts.where(post_type: :image, selected_for_analysis: true).count).to eq(0)
        end
      end
    end

    context "with ineligible posts mixed in" do
      before do
        create_eligible_posts(count: 5, type: :reel)
        3.times { create_ineligible_post(type: :reel) }
      end

      it "does not select ineligible posts even when eligible count is below limit" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          selected = analysis.posts.where(selected_for_analysis: true)
          expect(selected.count).to eq(5)
          expect(selected.all? { |p| p.quality_score > 0 }).to be(true)
        end
      end
    end

    it "calculates quality_score for all posts (including ineligible)" do
      create_eligible_posts(count: 3, type: :reel)
      create_ineligible_post(type: :reel)

      ActsAsTenant.with_tenant(account) do
        described_class.call(analysis)

        scored_count = analysis.posts.where.not(quality_score: nil).count
        expect(scored_count).to eq(4)

        ineligible = analysis.posts.find_by(likes_count: 1)
        expect(ineligible.quality_score).to eq(0.0)
      end
    end

    it "selects the top N posts by quality_score within each type" do
      ActsAsTenant.with_tenant(account) do
        low_reel  = create(:post, account: account, competitor: competitor, analysis: analysis,
                            post_type: :reel, likes_count: 100, comments_count: 10, posted_at: 15.days.ago)
        high_reel = create(:post, account: account, competitor: competitor, analysis: analysis,
                            post_type: :reel, likes_count: 1_000, comments_count: 100, posted_at: 15.days.ago)

        described_class.call(analysis)

        expect(high_reel.reload.selected_for_analysis).to be(true)
        expect(low_reel.reload.selected_for_analysis).to be(true) # both selected since only 2 reels and limit is 12
      end
    end

    context "proportional selection with max_posts=50 (caps apply)" do
      let(:analysis) do
        ActsAsTenant.with_tenant(account) do
          create(:analysis, account: account, competitor: competitor, status: :scoring, max_posts: 50)
        end
      end

      before do
        create_eligible_posts(count: 30, type: :reel)
        create_eligible_posts(count: 8, type: :carousel)
        create_eligible_posts(count: 4, type: :image)
      end

      it "selects up to cap (20) reels" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)
          expect(analysis.posts.where(post_type: :reel, selected_for_analysis: true).count).to eq(20)
        end
      end

      it "selects up to cap (8) carousels" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)
          expect(analysis.posts.where(post_type: :carousel, selected_for_analysis: true).count).to eq(8)
        end
      end

      it "selects available count (4) when below cap (5) for images" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)
          expect(analysis.posts.where(post_type: :image, selected_for_analysis: true).count).to eq(4)
        end
      end
    end

    context "when an exception occurs" do
      before do
        allow(Analyses::Scoring::Formula).to receive(:calculate).and_raise(StandardError, "boom")
        create_eligible_posts(count: 1, type: :reel)
      end

      it "returns failure result" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:scoring_exception)
        end
      end

      it "marks analysis as failed" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(analysis.reload.status).to eq("failed")
        end
      end
    end
  end
end
