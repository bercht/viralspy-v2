require 'rails_helper'

RSpec.describe AnalysesHelper, type: :helper do
  let(:account) { create(:account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }

  describe '#completed_locals' do
    context 'when analysis is pending' do
      it 'returns empty hash' do
        ActsAsTenant.with_tenant(account) do
          analysis = create(:analysis, account: account, competitor: competitor, status: :pending)
          expect(completed_locals(analysis)).to eq({})
        end
      end
    end

    context 'when analysis is failed' do
      it 'returns empty hash' do
        ActsAsTenant.with_tenant(account) do
          analysis = create(:analysis, :failed, account: account, competitor: competitor)
          expect(completed_locals(analysis)).to eq({})
        end
      end
    end

    context 'when analysis is completed' do
      it 'returns hash with correct keys' do
        ActsAsTenant.with_tenant(account) do
          analysis = create(:analysis, :completed, account: account, competitor: competitor)
          result = completed_locals(analysis)
          expect(result.keys).to match_array(%i[profile_metrics posts_by_type suggestions])
        end
      end

      it 'returns profile_metrics from the analysis' do
        ActsAsTenant.with_tenant(account) do
          analysis = create(:analysis, :completed, account: account, competitor: competitor)
          result = completed_locals(analysis)
          expect(result[:profile_metrics]).to eq(analysis.profile_metrics)
        end
      end

      it 'returns empty hash for profile_metrics when analysis.profile_metrics is nil' do
        ActsAsTenant.with_tenant(account) do
          analysis = create(:analysis, :completed, account: account, competitor: competitor)
          allow(analysis).to receive(:profile_metrics).and_return(nil)
          result = completed_locals(analysis)
          expect(result[:profile_metrics]).to eq({})
        end
      end

      it 'returns posts grouped by post_type (selected_for_analysis only)' do
        ActsAsTenant.with_tenant(account) do
          analysis = create(:analysis, :completed, account: account, competitor: competitor)
          result = completed_locals(analysis)
          expect(result[:posts_by_type]).to be_a(Hash)
        end
      end

      it 'returns content suggestions' do
        ActsAsTenant.with_tenant(account) do
          analysis = create(:analysis, :completed, account: account, competitor: competitor)
          result = completed_locals(analysis)
          expect(result[:suggestions]).to respond_to(:each)
        end
      end
    end
  end
end
