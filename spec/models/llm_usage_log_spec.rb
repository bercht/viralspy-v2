require 'rails_helper'

RSpec.describe LlmUsageLog, type: :model do
  let(:account) { create(:account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }
  let(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) } }

  describe 'validations' do
    it 'requires provider' do
      ActsAsTenant.with_tenant(account) do
        log = build(:llm_usage_log, account: account, provider: nil)
        expect(log).not_to be_valid
        expect(log.errors[:provider]).not_to be_empty
      end
    end

    it 'requires model' do
      ActsAsTenant.with_tenant(account) do
        log = build(:llm_usage_log, account: account, model: nil)
        expect(log).not_to be_valid
        expect(log.errors[:model]).not_to be_empty
      end
    end
  end

  describe 'associations' do
    it 'belongs to account' do
      ActsAsTenant.with_tenant(account) do
        log = build(:llm_usage_log, account: account)
        expect(log.account).to eq(account)
      end
    end

    it 'allows nil analysis (optional)' do
      ActsAsTenant.with_tenant(account) do
        log = build(:llm_usage_log, account: account, analysis: nil)
        expect(log).to be_valid
      end
    end

    it 'accepts analysis when provided' do
      ActsAsTenant.with_tenant(account) do
        log = build(:llm_usage_log, :with_analysis, account: account)
        expect(log.analysis).to be_present
      end
    end
  end

  describe 'analysis nullify on destroy' do
    it 'sets analysis_id to nil when analysis is destroyed' do
      ActsAsTenant.with_tenant(account) do
        log = create(:llm_usage_log, :with_analysis, account: account)
        analysis_id = log.analysis_id
        expect(analysis_id).to be_present
        log.analysis.destroy
        expect(log.reload.analysis_id).to be_nil
      end
    end
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders by created_at DESC' do
        ActsAsTenant.with_tenant(account) do
          older = create(:llm_usage_log, account: account, created_at: 2.days.ago)
          newer = create(:llm_usage_log, account: account, created_at: 1.hour.ago)
          expect(LlmUsageLog.recent.first).to eq(newer)
        end
      end
    end

    describe '.by_use_case' do
      it 'filters by use_case' do
        ActsAsTenant.with_tenant(account) do
          reel_log = create(:llm_usage_log, account: account, use_case: 'reel_analysis')
          other_log = create(:llm_usage_log, account: account, use_case: 'caption_gen')
          expect(LlmUsageLog.by_use_case('reel_analysis')).to include(reel_log)
          expect(LlmUsageLog.by_use_case('reel_analysis')).not_to include(other_log)
        end
      end
    end
  end

  describe 'multi-tenancy' do
    it 'raises when created without tenant' do
      expect {
        LlmUsageLog.create!(account: account, provider: 'openai', model: 'gpt-4o-mini')
      }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end

    it 'scopes queries to current tenant' do
      other_account = create(:account)
      ActsAsTenant.with_tenant(account) { create(:llm_usage_log, account: account) }
      ActsAsTenant.with_tenant(other_account) { create(:llm_usage_log, account: other_account) }

      ActsAsTenant.with_tenant(account) do
        expect(LlmUsageLog.count).to eq(1)
      end
    end
  end
end
