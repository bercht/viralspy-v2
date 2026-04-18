require 'rails_helper'

RSpec.describe 'Multi-tenancy isolation', type: :model do
  let(:account_a) { create(:account, name: 'Account A') }
  let(:account_b) { create(:account, name: 'Account B') }

  it 'isolates all domain models by tenant' do
    ActsAsTenant.with_tenant(account_a) do
      competitor_a = create(:competitor, account: account_a)
      analysis_a = create(:analysis, account: account_a, competitor: competitor_a)
      create(:post, :reel, account: account_a, analysis: analysis_a, competitor: competitor_a)
      create(:content_suggestion, account: account_a, analysis: analysis_a)
      create(:llm_usage_log, account: account_a, analysis: analysis_a)
      create(:transcription_usage_log, account: account_a, analysis: analysis_a)
    end

    ActsAsTenant.with_tenant(account_b) do
      competitor_b = create(:competitor, account: account_b)
      analysis_b = create(:analysis, account: account_b, competitor: competitor_b)
      create(:post, :carousel, account: account_b, analysis: analysis_b, competitor: competitor_b)
      create(:content_suggestion, account: account_b, analysis: analysis_b)
    end

    ActsAsTenant.with_tenant(account_a) do
      expect(Competitor.count).to eq(1)
      expect(Analysis.count).to eq(1)
      expect(Post.count).to eq(1)
      expect(ContentSuggestion.count).to eq(1)
      expect(LlmUsageLog.count).to eq(1)
      expect(TranscriptionUsageLog.count).to eq(1)
    end

    ActsAsTenant.with_tenant(account_b) do
      expect(Competitor.count).to eq(1)
      expect(Analysis.count).to eq(1)
      expect(Post.count).to eq(1)
      expect(ContentSuggestion.count).to eq(1)
      expect(LlmUsageLog.count).to eq(0)
      expect(TranscriptionUsageLog.count).to eq(0)
    end
  end

  it 'raises NoTenantSet on create without tenant for all domain models' do
    expect { Competitor.create!(account: account_a, instagram_handle: 'foo') }.to raise_error(ActsAsTenant::Errors::NoTenantSet)

    competitor = ActsAsTenant.with_tenant(account_a) { create(:competitor, account: account_a) }
    expect { Analysis.create!(account: account_a, competitor: competitor) }.to raise_error(ActsAsTenant::Errors::NoTenantSet)

    analysis = ActsAsTenant.with_tenant(account_a) { create(:analysis, account: account_a, competitor: competitor) }
    expect {
      Post.create!(account: account_a, analysis: analysis, competitor: competitor, instagram_post_id: 'x', post_type: :reel)
    }.to raise_error(ActsAsTenant::Errors::NoTenantSet)

    expect {
      ContentSuggestion.create!(account: account_a, analysis: analysis, position: 1, content_type: :reel)
    }.to raise_error(ActsAsTenant::Errors::NoTenantSet)

    expect {
      LlmUsageLog.create!(account: account_a, provider: 'openai', model: 'gpt-4o-mini')
    }.to raise_error(ActsAsTenant::Errors::NoTenantSet)

    expect {
      TranscriptionUsageLog.create!(account: account_a, provider: 'openai', model: 'whisper-1')
    }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
  end
end
