require 'rails_helper'

RSpec.describe Competitor, type: :model do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'requires instagram_handle' do
      ActsAsTenant.with_tenant(account) do
        competitor = build(:competitor, account: account, instagram_handle: nil)
        expect(competitor).not_to be_valid
        expect(competitor.errors[:instagram_handle]).not_to be_empty
      end
    end

    it 'accepts valid handle formats' do
      ActsAsTenant.with_tenant(account) do
        valid_handles = [ 'foo', 'foo_bar', 'foo.bar', 'Foo123', 'a' * 30 ]
        valid_handles.each do |h|
          competitor = build(:competitor, account: account, instagram_handle: h)
          expect(competitor).to be_valid, "expected '#{h}' to be valid"
        end
      end
    end

    it 'rejects invalid handle formats' do
      ActsAsTenant.with_tenant(account) do
        invalid_handles = [ 'foo bar', 'foo@bar', 'foo-bar', 'a' * 31, '' ]
        invalid_handles.each do |h|
          competitor = build(:competitor, account: account, instagram_handle: h)
          expect(competitor).not_to be_valid, "expected '#{h}' to be invalid"
        end
      end
    end

    it 'enforces uniqueness per account (case-insensitive)' do
      ActsAsTenant.with_tenant(account) do
        create(:competitor, account: account, instagram_handle: 'foo')
        duplicate = build(:competitor, account: account, instagram_handle: 'FOO')
        expect(duplicate).not_to be_valid
      end
    end

    it 'allows same handle across different accounts' do
      other_account = create(:account)
      ActsAsTenant.with_tenant(account) do
        create(:competitor, account: account, instagram_handle: 'shared')
      end
      ActsAsTenant.with_tenant(other_account) do
        duplicate = build(:competitor, account: other_account, instagram_handle: 'shared')
        expect(duplicate).to be_valid
      end
    end
  end

  describe 'callbacks' do
    it 'normalizes handle before validation' do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account, instagram_handle: '  @FooBar  ')
        expect(competitor.instagram_handle).to eq('foobar')
      end
    end
  end

  describe 'associations' do
    it 'belongs to account' do
      ActsAsTenant.with_tenant(account) do
        competitor = build(:competitor, account: account)
        expect(competitor.account).to eq(account)
      end
    end
  end

  describe 'multi-tenancy' do
    it 'raises when created without tenant' do
      expect {
        Competitor.create!(instagram_handle: 'foo', account: account)
      }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end

    it 'scopes queries to current tenant' do
      other_account = create(:account)
      ActsAsTenant.with_tenant(account) { create(:competitor, account: account) }
      ActsAsTenant.with_tenant(other_account) { create(:competitor, account: other_account) }

      ActsAsTenant.with_tenant(account) do
        expect(Competitor.count).to eq(1)
      end
    end
  end

  describe '.recent' do
    it 'orders by created_at DESC' do
      ActsAsTenant.with_tenant(account) do
        older = create(:competitor, account: account, created_at: 2.days.ago)
        newer = create(:competitor, account: account, created_at: 1.hour.ago)
        expect(Competitor.recent).to eq([ newer, older ])
      end
    end
  end

  describe 'niche' do
    it 'is optional' do
      ActsAsTenant.with_tenant(account) do
        competitor = build(:competitor, account: account, niche: nil)
        expect(competitor).to be_valid
      end
    end

    it 'accepts up to 120 characters' do
      ActsAsTenant.with_tenant(account) do
        competitor = build(:competitor, account: account, niche: 'N' * 120)
        expect(competitor).to be_valid
      end
    end

    it 'rejects more than 120 characters' do
      ActsAsTenant.with_tenant(account) do
        competitor = build(:competitor, account: account, niche: 'N' * 121)
        expect(competitor).not_to be_valid
        expect(competitor.errors[:niche]).not_to be_empty
      end
    end

    it 'strips whitespace from niche before save' do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account, niche: '  Nutrição funcional  ')
        expect(competitor.niche).to eq('Nutrição funcional')
      end
    end
  end

  describe '#niche_for_prompt' do
    let(:playbook) { create(:playbook, account: account, niche: 'Fitness') }

    it 'returns own niche when present' do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account, niche: 'Nutrição funcional')
        expect(competitor.niche_for_prompt).to eq('Nutrição funcional')
      end
    end

    it 'falls back to first associated playbook niche when own niche is blank' do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account, niche: nil)
        analysis = create(:analysis, account: account, competitor: competitor)
        create(:analysis_playbook, analysis: analysis, playbook: playbook)
        expect(competitor.niche_for_prompt(analysis: analysis)).to eq('Fitness')
      end
    end

    it 'returns the neutral fallback string when no niche is set anywhere' do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account, niche: nil)
        expect(competitor.niche_for_prompt).to eq('conteúdo de Instagram em português brasileiro')
      end
    end

    it 'prefers own niche over playbook niche' do
      ActsAsTenant.with_tenant(account) do
        competitor = create(:competitor, account: account, niche: 'Nutrição funcional')
        analysis = create(:analysis, account: account, competitor: competitor)
        create(:analysis_playbook, analysis: analysis, playbook: playbook)
        expect(competitor.niche_for_prompt(analysis: analysis)).to eq('Nutrição funcional')
      end
    end
  end
end
