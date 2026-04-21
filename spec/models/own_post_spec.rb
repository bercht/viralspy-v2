require 'rails_helper'

RSpec.describe OwnPost, type: :model do
  let(:account) { create(:account) }
  let(:own_profile) { ActsAsTenant.with_tenant(account) { create(:own_profile, account: account) } }

  describe 'validations' do
    it 'requires post_type' do
      ActsAsTenant.with_tenant(account) do
        post = build(:own_post, account: account, own_profile: own_profile, post_type: nil)
        expect(post).not_to be_valid
        expect(post.errors[:post_type]).not_to be_empty
      end
    end

    it 'validates uniqueness of instagram_post_id scoped to own_profile_id' do
      ActsAsTenant.with_tenant(account) do
        create(:own_post, account: account, own_profile: own_profile, instagram_post_id: 'ig_123')
        duplicate = build(:own_post, account: account, own_profile: own_profile,
          instagram_post_id: 'ig_123')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:instagram_post_id]).not_to be_empty
      end
    end

    it 'allows nil instagram_post_id' do
      ActsAsTenant.with_tenant(account) do
        post = build(:own_post, account: account, own_profile: own_profile,
          instagram_post_id: nil)
        expect(post).to be_valid
      end
    end
  end

  describe '#engagement_rate' do
    it 'delegates to the metrics hash' do
      ActsAsTenant.with_tenant(account) do
        post = build(:own_post, account: account, own_profile: own_profile,
          metrics: { 'engagement_rate' => 4.5 })
        expect(post.engagement_rate).to eq(4.5)
      end
    end

    it 'returns nil when engagement_rate is absent from metrics' do
      ActsAsTenant.with_tenant(account) do
        post = build(:own_post, account: account, own_profile: own_profile, metrics: {})
        expect(post.engagement_rate).to be_nil
      end
    end
  end

  describe '#add_metrics_snapshot' do
    it 'sets metrics to the new metrics hash' do
      ActsAsTenant.with_tenant(account) do
        post = create(:own_post, account: account, own_profile: own_profile, metrics: {})
        new_metrics = { 'reach' => 1000, 'plays' => 3000 }
        post.add_metrics_snapshot(new_metrics)
        expect(post.metrics['reach']).to eq(1000)
        expect(post.metrics['plays']).to eq(3000)
      end
    end

    it 'appends a snapshot with captured_at to metrics_history' do
      ActsAsTenant.with_tenant(account) do
        post = create(:own_post, account: account, own_profile: own_profile,
          metrics: {}, metrics_history: [])
        new_metrics = { 'reach' => 500 }
        post.add_metrics_snapshot(new_metrics)
        expect(post.metrics_history.length).to eq(1)
        expect(post.metrics_history.first['reach']).to eq(500)
        expect(post.metrics_history.first['captured_at']).to be_present
      end
    end

    it 'accumulates multiple snapshots in history' do
      ActsAsTenant.with_tenant(account) do
        post = create(:own_post, account: account, own_profile: own_profile,
          metrics: {}, metrics_history: [])
        post.add_metrics_snapshot({ 'reach' => 500 })
        post.add_metrics_snapshot({ 'reach' => 800 })
        expect(post.metrics_history.length).to eq(2)
      end
    end

    it 'updates metrics_last_fetched_at' do
      ActsAsTenant.with_tenant(account) do
        post = create(:own_post, account: account, own_profile: own_profile)
        freeze_time do
          post.add_metrics_snapshot({ 'reach' => 100 })
          expect(post.metrics_last_fetched_at).to be_within(1.second).of(Time.current)
        end
      end
    end
  end
end
