require 'rails_helper'

RSpec.describe ContentSuggestion, type: :model do
  let(:account) { create(:account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }
  let(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) } }

  describe 'validations' do
    it 'requires position' do
      ActsAsTenant.with_tenant(account) do
        suggestion = build(:content_suggestion, account: account, analysis: analysis, position: nil)
        expect(suggestion).not_to be_valid
        expect(suggestion.errors[:position]).not_to be_empty
      end
    end

    it 'requires position to be an integer >= 1' do
      ActsAsTenant.with_tenant(account) do
        suggestion = build(:content_suggestion, account: account, analysis: analysis, position: 0)
        expect(suggestion).not_to be_valid
      end
    end

    it 'enforces position uniqueness within analysis' do
      ActsAsTenant.with_tenant(account) do
        create(:content_suggestion, account: account, analysis: analysis, position: 1)
        duplicate = build(:content_suggestion, account: account, analysis: analysis, position: 1)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:position]).not_to be_empty
      end
    end

    it 'allows same position across different analyses' do
      other_analysis = ActsAsTenant.with_tenant(account) { create(:analysis, account: account, competitor: competitor) }
      ActsAsTenant.with_tenant(account) do
        create(:content_suggestion, account: account, analysis: analysis, position: 1)
        other = build(:content_suggestion, account: account, analysis: other_analysis, position: 1)
        expect(other).to be_valid
      end
    end

    it 'requires content_type' do
      ActsAsTenant.with_tenant(account) do
        suggestion = build(:content_suggestion, account: account, analysis: analysis)
        suggestion.content_type = nil
        expect(suggestion).not_to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to account' do
      ActsAsTenant.with_tenant(account) do
        suggestion = build(:content_suggestion, account: account, analysis: analysis)
        expect(suggestion.account).to eq(account)
      end
    end

    it 'belongs to analysis' do
      ActsAsTenant.with_tenant(account) do
        suggestion = build(:content_suggestion, account: account, analysis: analysis)
        expect(suggestion.analysis).to eq(analysis)
      end
    end
  end

  describe 'enums' do
    describe 'content_type' do
      it 'defines reel, carousel, image with prefix :content' do
        expect(ContentSuggestion.content_types.keys).to match_array(%w[reel carousel image])
      end

      it 'generates prefixed predicates' do
        ActsAsTenant.with_tenant(account) do
          suggestion = build(:content_suggestion, :reel, account: account, analysis: analysis)
          expect(suggestion.content_reel?).to be true
          expect(suggestion.content_carousel?).to be false
        end
      end
    end

    describe 'status' do
      it 'defines draft, saved, discarded' do
        expect(ContentSuggestion.statuses.keys).to match_array(%w[draft saved discarded])
      end

      it 'defaults to draft' do
        ActsAsTenant.with_tenant(account) do
          suggestion = create(:content_suggestion, account: account, analysis: analysis)
          expect(suggestion.draft?).to be true
        end
      end

      it 'generates predicates' do
        ActsAsTenant.with_tenant(account) do
          suggestion = build(:content_suggestion, :saved, account: account, analysis: analysis)
          expect(suggestion.saved?).to be true
          expect(suggestion.draft?).to be false
        end
      end
    end
  end

  describe 'scopes' do
    describe '.ordered' do
      it 'orders by position ASC' do
        ActsAsTenant.with_tenant(account) do
          third = create(:content_suggestion, account: account, analysis: analysis, position: 3)
          first = create(:content_suggestion, account: account, analysis: analysis, position: 1)
          second = create(:content_suggestion, account: account, analysis: analysis, position: 2)
          expect(ContentSuggestion.ordered).to eq([ first, second, third ])
        end
      end
    end

    describe '.by_content_type' do
      it 'filters by content type' do
        ActsAsTenant.with_tenant(account) do
          reel_s = create(:content_suggestion, :reel, account: account, analysis: analysis, position: 1)
          carousel_s = create(:content_suggestion, :carousel, account: account, analysis: analysis, position: 2)
          expect(ContentSuggestion.by_content_type(:reel)).to include(reel_s)
          expect(ContentSuggestion.by_content_type(:reel)).not_to include(carousel_s)
        end
      end
    end
  end

  describe 'DB uniqueness constraint' do
    it 'raises on duplicate (analysis_id, position) bypassing model validations' do
      ActsAsTenant.with_tenant(account) do
        create(:content_suggestion, account: account, analysis: analysis, position: 1)
        duplicate = build(:content_suggestion, account: account, analysis: analysis, position: 1)
        expect {
          duplicate.save(validate: false)
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe 'jsonb defaults' do
    it 'defaults format_details to {}' do
      ActsAsTenant.with_tenant(account) do
        suggestion = create(:content_suggestion, account: account, analysis: analysis, format_details: {})
        expect(suggestion.reload.format_details).to eq({})
      end
    end

    it 'defaults suggested_hashtags to []' do
      ActsAsTenant.with_tenant(account) do
        suggestion = create(:content_suggestion, account: account, analysis: analysis, suggested_hashtags: [])
        expect(suggestion.reload.suggested_hashtags).to eq([])
      end
    end
  end

  describe 'multi-tenancy' do
    it 'raises when created without tenant' do
      expect {
        ContentSuggestion.create!(account: account, analysis: analysis, position: 1, content_type: :reel)
      }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end

    it 'scopes queries to current tenant' do
      other_account = create(:account)
      other_competitor = ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }
      other_analysis = ActsAsTenant.with_tenant(other_account) { create(:analysis, account: other_account, competitor: other_competitor) }

      ActsAsTenant.with_tenant(account) { create(:content_suggestion, account: account, analysis: analysis) }
      ActsAsTenant.with_tenant(other_account) { create(:content_suggestion, account: other_account, analysis: other_analysis) }

      ActsAsTenant.with_tenant(account) do
        expect(ContentSuggestion.count).to eq(1)
      end
    end
  end
end
