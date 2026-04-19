require 'rails_helper'

RSpec.describe Analysis, type: :model do
  let(:account) { create(:account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }

  describe 'associations' do
    it 'belongs to account' do
      ActsAsTenant.with_tenant(account) do
        analysis = build(:analysis, account: account, competitor: competitor)
        expect(analysis.account).to eq(account)
      end
    end

    it 'belongs to competitor' do
      ActsAsTenant.with_tenant(account) do
        analysis = build(:analysis, account: account, competitor: competitor)
        expect(analysis.competitor).to eq(competitor)
      end
    end

    it 'has many posts with destroy' do
      ref = Analysis.reflect_on_association(:posts)
      expect(ref.macro).to eq(:has_many)
      expect(ref.options[:dependent]).to eq(:destroy)
    end

    it 'has many content_suggestions with destroy' do
      ref = Analysis.reflect_on_association(:content_suggestions)
      expect(ref.macro).to eq(:has_many)
      expect(ref.options[:dependent]).to eq(:destroy)
    end

    it 'has many llm_usage_logs with nullify' do
      ref = Analysis.reflect_on_association(:llm_usage_logs)
      expect(ref.macro).to eq(:has_many)
      expect(ref.options[:dependent]).to eq(:nullify)
    end

    it 'has many transcription_usage_logs with nullify' do
      ref = Analysis.reflect_on_association(:transcription_usage_logs)
      expect(ref.macro).to eq(:has_many)
      expect(ref.options[:dependent]).to eq(:nullify)
    end
  end

  describe 'validations' do
    describe 'max_posts' do
      it 'accepts 10 (minimum)' do
        ActsAsTenant.with_tenant(account) do
          a = build(:analysis, account: account, competitor: competitor, max_posts: 10)
          expect(a).to be_valid
        end
      end

      it 'accepts 100 (maximum)' do
        ActsAsTenant.with_tenant(account) do
          a = build(:analysis, account: account, competitor: competitor, max_posts: 100)
          expect(a).to be_valid
        end
      end

      it 'rejects 9 (below minimum)' do
        ActsAsTenant.with_tenant(account) do
          a = build(:analysis, account: account, competitor: competitor, max_posts: 9)
          expect(a).not_to be_valid
        end
      end

      it 'rejects 101 (above maximum)' do
        ActsAsTenant.with_tenant(account) do
          a = build(:analysis, account: account, competitor: competitor, max_posts: 101)
          expect(a).not_to be_valid
        end
      end

      it 'rejects non-integer' do
        ActsAsTenant.with_tenant(account) do
          a = build(:analysis, account: account, competitor: competitor, max_posts: 50.5)
          expect(a).not_to be_valid
        end
      end
    end
  end

  describe 'enums' do
    describe '#status' do
      it 'defines 9 states including refining' do
        expect(Analysis.statuses.keys).to match_array(
          %w[pending scraping scoring transcribing analyzing generating_suggestions refining completed failed]
        )
      end

      it 'has refining at value 6' do
        expect(Analysis.statuses['refining']).to eq(6)
      end

      it 'has completed at value 7' do
        expect(Analysis.statuses['completed']).to eq(7)
      end

      it 'has failed at value 8' do
        expect(Analysis.statuses['failed']).to eq(8)
      end

      it 'defaults to pending' do
        ActsAsTenant.with_tenant(account) do
          analysis = create(:analysis, account: account, competitor: competitor)
          expect(analysis.pending?).to be true
        end
      end

      it 'generates predicates for each state' do
        ActsAsTenant.with_tenant(account) do
          analysis = build(:analysis, :completed, account: account, competitor: competitor)
          expect(analysis.completed?).to be true
          expect(analysis.pending?).to be false
          expect(analysis.failed?).to be false
        end
      end

      it 'generates predicates for failed state' do
        ActsAsTenant.with_tenant(account) do
          analysis = build(:analysis, :failed, account: account, competitor: competitor)
          expect(analysis.failed?).to be true
        end
      end
    end
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders by created_at DESC' do
        ActsAsTenant.with_tenant(account) do
          older = create(:analysis, account: account, competitor: competitor, created_at: 2.days.ago)
          newer = create(:analysis, account: account, competitor: competitor, created_at: 1.hour.ago)
          expect(Analysis.recent).to eq([ newer, older ])
        end
      end
    end

    describe '.in_progress' do
      it 'returns analyses with pending/scraping/scoring/transcribing/analyzing/generating_suggestions status' do
        ActsAsTenant.with_tenant(account) do
          pending_a   = create(:analysis, account: account, competitor: competitor, status: :pending)
          scraping_a  = create(:analysis, account: account, competitor: competitor, status: :scraping)
          scoring_a   = create(:analysis, account: account, competitor: competitor, status: :scoring)
          completed_a = create(:analysis, :completed, account: account, competitor: competitor)
          failed_a    = create(:analysis, :failed, account: account, competitor: competitor)

          in_progress = Analysis.in_progress
          expect(in_progress).to include(pending_a, scraping_a, scoring_a)
          expect(in_progress).not_to include(completed_a, failed_a)
        end
      end
    end
  end

  describe '#duration_seconds' do
    it 'returns nil when started_at is missing' do
      ActsAsTenant.with_tenant(account) do
        analysis = build(:analysis, account: account, competitor: competitor, started_at: nil, finished_at: Time.current)
        expect(analysis.duration_seconds).to be_nil
      end
    end

    it 'returns nil when finished_at is missing' do
      ActsAsTenant.with_tenant(account) do
        analysis = build(:analysis, account: account, competitor: competitor, started_at: 5.minutes.ago, finished_at: nil)
        expect(analysis.duration_seconds).to be_nil
      end
    end

    it 'returns elapsed seconds when both timestamps present' do
      ActsAsTenant.with_tenant(account) do
        start = 5.minutes.ago
        finish = start + 120.seconds
        analysis = build(:analysis, :completed, account: account, competitor: competitor,
                         started_at: start, finished_at: finish)
        expect(analysis.duration_seconds).to eq(120)
      end
    end
  end

  describe 'jsonb defaults' do
    it 'defaults raw_data to {}' do
      ActsAsTenant.with_tenant(account) do
        analysis = create(:analysis, account: account, competitor: competitor)
        expect(analysis.raw_data).to eq({})
      end
    end

    it 'defaults profile_metrics to {}' do
      ActsAsTenant.with_tenant(account) do
        analysis = create(:analysis, account: account, competitor: competitor)
        expect(analysis.profile_metrics).to eq({})
      end
    end

    it 'defaults insights to {}' do
      ActsAsTenant.with_tenant(account) do
        analysis = create(:analysis, account: account, competitor: competitor)
        expect(analysis.insights).to eq({})
      end
    end
  end

  describe 'multi-tenancy' do
    it 'raises when created without tenant' do
      expect {
        Analysis.create!(account: account, competitor: competitor)
      }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end

    it 'scopes queries to current tenant' do
      other_account = create(:account)
      other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }

      ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) }
      ActsAsTenant.with_tenant(other_account) { create(:analysis, account: other_account, competitor: other_competitor) }

      ActsAsTenant.with_tenant(account) do
        expect(Analysis.count).to eq(1)
      end
    end
  end
end
