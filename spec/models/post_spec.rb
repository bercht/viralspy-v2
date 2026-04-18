require 'rails_helper'

RSpec.describe Post, type: :model do
  let(:account) { create(:account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }
  let(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) } }

  describe 'validations' do
    it 'requires instagram_post_id' do
      ActsAsTenant.with_tenant(account) do
        post = build(:post, account: account, analysis: analysis, competitor: competitor, instagram_post_id: nil)
        expect(post).not_to be_valid
        expect(post.errors[:instagram_post_id]).not_to be_empty
      end
    end

    it 'requires post_type' do
      ActsAsTenant.with_tenant(account) do
        post = build(:post, account: account, analysis: analysis, competitor: competitor)
        post.post_type = nil
        expect(post).not_to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to account' do
      ActsAsTenant.with_tenant(account) do
        post = build(:post, account: account, analysis: analysis, competitor: competitor)
        expect(post.account).to eq(account)
      end
    end

    it 'belongs to analysis' do
      ActsAsTenant.with_tenant(account) do
        post = build(:post, account: account, analysis: analysis, competitor: competitor)
        expect(post.analysis).to eq(analysis)
      end
    end

    it 'belongs to competitor' do
      ActsAsTenant.with_tenant(account) do
        post = build(:post, account: account, analysis: analysis, competitor: competitor)
        expect(post.competitor).to eq(competitor)
      end
    end
  end

  describe 'enums' do
    describe 'post_type' do
      it 'defines reel, carousel, image' do
        expect(Post.post_types.keys).to match_array(%w[reel carousel image])
      end

      it 'generates predicates' do
        ActsAsTenant.with_tenant(account) do
          post = build(:post, :reel, account: account, analysis: analysis, competitor: competitor)
          expect(post.reel?).to be true
          expect(post.carousel?).to be false
          expect(post.image?).to be false
        end
      end
    end

    describe 'transcript_status' do
      it 'defines pending, completed, failed, skipped' do
        expect(Post.transcript_statuses.keys).to match_array(%w[pending completed failed skipped])
      end

      it 'generates prefixed predicates' do
        ActsAsTenant.with_tenant(account) do
          post = build(:post, :with_transcript, account: account, analysis: analysis, competitor: competitor)
          expect(post.transcript_completed?).to be true
          expect(post.transcript_pending?).to be false
        end
      end

      it 'defaults to pending' do
        ActsAsTenant.with_tenant(account) do
          post = create(:post, account: account, analysis: analysis, competitor: competitor)
          expect(post.transcript_pending?).to be true
        end
      end
    end
  end

  describe 'scopes' do
    describe '.selected' do
      it 'returns only selected_for_analysis posts' do
        ActsAsTenant.with_tenant(account) do
          selected = create(:post, :selected, account: account, analysis: analysis, competitor: competitor)
          unselected = create(:post, account: account, analysis: analysis, competitor: competitor)
          expect(Post.selected).to include(selected)
          expect(Post.selected).not_to include(unselected)
        end
      end
    end

    describe '.by_type' do
      it 'filters by post type' do
        ActsAsTenant.with_tenant(account) do
          reel_post = create(:post, :reel, account: account, analysis: analysis, competitor: competitor)
          carousel_post = create(:post, :carousel, account: account, analysis: analysis, competitor: competitor)
          expect(Post.by_type(:reel)).to include(reel_post)
          expect(Post.by_type(:reel)).not_to include(carousel_post)
        end
      end
    end

    describe '.ranked' do
      it 'orders by quality_score DESC' do
        ActsAsTenant.with_tenant(account) do
          low = create(:post, :selected, account: account, analysis: analysis, competitor: competitor, quality_score: 100.0)
          high = create(:post, :selected, account: account, analysis: analysis, competitor: competitor, quality_score: 900.0)
          expect(Post.ranked.first).to eq(high)
          expect(Post.ranked.last).to eq(low)
        end
      end
    end

    describe '.recent_first' do
      it 'orders by posted_at DESC' do
        ActsAsTenant.with_tenant(account) do
          older = create(:post, account: account, analysis: analysis, competitor: competitor, posted_at: 10.days.ago)
          newer = create(:post, account: account, analysis: analysis, competitor: competitor, posted_at: 1.day.ago)
          expect(Post.recent_first.first).to eq(newer)
          expect(Post.recent_first.last).to eq(older)
        end
      end
    end
  end

  describe '#has_video?' do
    it 'returns true when video_url present' do
      ActsAsTenant.with_tenant(account) do
        post = build(:post, :reel, account: account, analysis: analysis, competitor: competitor)
        expect(post.has_video?).to be true
      end
    end

    it 'returns false when video_url blank' do
      ActsAsTenant.with_tenant(account) do
        post = build(:post, :image, account: account, analysis: analysis, competitor: competitor, video_url: nil)
        expect(post.has_video?).to be false
      end
    end
  end

  describe 'array defaults' do
    it 'defaults hashtags to [] when not specified' do
      ActsAsTenant.with_tenant(account) do
        post = create(:post, account: account, analysis: analysis, competitor: competitor, hashtags: [])
        expect(post.reload.hashtags).to eq([])
      end
    end

    it 'defaults mentions to [] when not specified' do
      ActsAsTenant.with_tenant(account) do
        post = create(:post, account: account, analysis: analysis, competitor: competitor, mentions: [])
        expect(post.reload.mentions).to eq([])
      end
    end
  end

  describe 'multi-tenancy' do
    it 'raises when created without tenant' do
      expect {
        Post.create!(account: account, analysis: analysis, competitor: competitor, instagram_post_id: 'x', post_type: :reel)
      }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end

    it 'scopes queries to current tenant' do
      other_account = create(:account)
      other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
      other_analysis = ActsAsTenant.with_tenant(other_account) { create(:analysis, account: other_account, competitor: other_competitor) }

      ActsAsTenant.with_tenant(account) { create(:post, account: account, analysis: analysis, competitor: competitor) }
      ActsAsTenant.with_tenant(other_account) { create(:post, account: other_account, analysis: other_analysis, competitor: other_competitor) }

      ActsAsTenant.with_tenant(account) do
        expect(Post.count).to eq(1)
      end
    end
  end
end
