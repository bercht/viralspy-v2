require 'rails_helper'

RSpec.describe TranscriptionUsageLog, type: :model do
  let(:account) { create(:account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }
  let(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) } }

  describe 'validations' do
    it 'requires provider' do
      ActsAsTenant.with_tenant(account) do
        log = build(:transcription_usage_log, account: account, provider: nil)
        expect(log).not_to be_valid
        expect(log.errors[:provider]).not_to be_empty
      end
    end

    it 'requires model' do
      ActsAsTenant.with_tenant(account) do
        log = build(:transcription_usage_log, account: account, model: nil)
        expect(log).not_to be_valid
        expect(log.errors[:model]).not_to be_empty
      end
    end
  end

  describe 'associations' do
    it 'belongs to account' do
      ActsAsTenant.with_tenant(account) do
        log = build(:transcription_usage_log, account: account)
        expect(log.account).to eq(account)
      end
    end

    it 'allows nil analysis (optional)' do
      ActsAsTenant.with_tenant(account) do
        log = build(:transcription_usage_log, account: account, analysis: nil)
        expect(log).to be_valid
      end
    end

    it 'allows nil post (optional)' do
      ActsAsTenant.with_tenant(account) do
        log = build(:transcription_usage_log, account: account, post: nil)
        expect(log).to be_valid
      end
    end

    it 'accepts post when provided via trait' do
      ActsAsTenant.with_tenant(account) do
        log = create(:transcription_usage_log, :with_post, account: account)
        expect(log.post).to be_a(Post)
        expect(log.analysis).to be_a(Analysis)
      end
    end
  end

  describe 'analysis nullify on destroy' do
    it 'sets analysis_id to nil when analysis is destroyed' do
      ActsAsTenant.with_tenant(account) do
        log = create(:transcription_usage_log, account: account, analysis: analysis)
        analysis.destroy
        expect(log.reload.analysis_id).to be_nil
      end
    end
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders by created_at DESC' do
        ActsAsTenant.with_tenant(account) do
          older = create(:transcription_usage_log, account: account, created_at: 2.days.ago)
          newer = create(:transcription_usage_log, account: account, created_at: 1.hour.ago)
          expect(TranscriptionUsageLog.recent.first).to eq(newer)
        end
      end
    end
  end

  describe 'multi-tenancy' do
    it 'raises when created without tenant' do
      expect {
        TranscriptionUsageLog.create!(account: account, provider: 'openai', model: 'whisper-1')
      }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end

    it 'scopes queries to current tenant' do
      other_account = create(:account)
      ActsAsTenant.with_tenant(account) { create(:transcription_usage_log, account: account) }
      ActsAsTenant.with_tenant(other_account) { create(:transcription_usage_log, account: other_account) }

      ActsAsTenant.with_tenant(account) do
        expect(TranscriptionUsageLog.count).to eq(1)
      end
    end
  end
end
