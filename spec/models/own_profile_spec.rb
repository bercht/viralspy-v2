require 'rails_helper'

RSpec.describe OwnProfile, type: :model do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'requires instagram_handle' do
      ActsAsTenant.with_tenant(account) do
        profile = build(:own_profile, account: account, instagram_handle: nil)
        expect(profile).not_to be_valid
        expect(profile.errors[:instagram_handle]).not_to be_empty
      end
    end

    it 'validates uniqueness of instagram_handle scoped to account_id' do
      ActsAsTenant.with_tenant(account) do
        create(:own_profile, account: account, instagram_handle: 'myperfil')
        duplicate = build(:own_profile, account: account, instagram_handle: 'myperfil')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:instagram_handle]).not_to be_empty
      end
    end

    it 'allows same handle in different accounts' do
      other_account = create(:account)
      ActsAsTenant.with_tenant(account) do
        create(:own_profile, account: account, instagram_handle: 'myperfil')
      end
      ActsAsTenant.with_tenant(other_account) do
        profile = build(:own_profile, account: other_account, instagram_handle: 'myperfil')
        expect(profile).to be_valid
      end
    end
  end

  describe 'handle normalization' do
    it 'strips leading @ from handle' do
      ActsAsTenant.with_tenant(account) do
        profile = create(:own_profile, account: account, instagram_handle: '@meuperfil')
        expect(profile.instagram_handle).to eq('meuperfil')
      end
    end

    it 'downcases the handle' do
      ActsAsTenant.with_tenant(account) do
        profile = create(:own_profile, account: account, instagram_handle: 'MeuPerfil')
        expect(profile.instagram_handle).to eq('meuperfil')
      end
    end

    it 'strips whitespace from handle' do
      ActsAsTenant.with_tenant(account) do
        profile = create(:own_profile, account: account, instagram_handle: '  meuperfil  ')
        expect(profile.instagram_handle).to eq('meuperfil')
      end
    end
  end

  describe '#token_valid?' do
    it 'returns true when token is present and expires_at is in the future' do
      ActsAsTenant.with_tenant(account) do
        profile = build(:own_profile, :with_token, account: account)
        expect(profile.token_valid?).to be true
      end
    end

    it 'returns false when meta_access_token is blank' do
      ActsAsTenant.with_tenant(account) do
        profile = build(:own_profile, account: account,
          meta_access_token: nil, meta_token_expires_at: 1.day.from_now)
        expect(profile.token_valid?).to be false
      end
    end

    it 'returns false when expires_at is in the past' do
      ActsAsTenant.with_tenant(account) do
        profile = build(:own_profile, :with_expired_token, account: account)
        expect(profile.token_valid?).to be false
      end
    end
  end

  describe '#token_expiring_soon?' do
    it 'returns true when expires_at is within 7 days' do
      ActsAsTenant.with_tenant(account) do
        profile = build(:own_profile, :with_expiring_token, account: account)
        expect(profile.token_expiring_soon?).to be true
      end
    end

    it 'returns false when expires_at is beyond 7 days' do
      ActsAsTenant.with_tenant(account) do
        profile = build(:own_profile, :with_token, account: account)
        expect(profile.token_expiring_soon?).to be false
      end
    end

    it 'returns false when expires_at is nil' do
      ActsAsTenant.with_tenant(account) do
        profile = build(:own_profile, account: account, meta_token_expires_at: nil)
        expect(profile.token_expiring_soon?).to be false
      end
    end
  end

  describe 'scopes' do
    it 'with_valid_token includes profiles with token and future expires_at' do
      ActsAsTenant.with_tenant(account) do
        valid = create(:own_profile, :with_token, account: account)
        expired = create(:own_profile, :with_expired_token, account: account)
        expect(OwnProfile.with_valid_token).to include(valid)
        expect(OwnProfile.with_valid_token).not_to include(expired)
      end
    end

    it 'expiring_soon includes profiles expiring within 7 days' do
      ActsAsTenant.with_tenant(account) do
        expiring = create(:own_profile, :with_expiring_token, account: account)
        valid    = create(:own_profile, :with_token, account: account)
        expect(OwnProfile.expiring_soon).to include(expiring)
        expect(OwnProfile.expiring_soon).not_to include(valid)
      end
    end
  end
end
