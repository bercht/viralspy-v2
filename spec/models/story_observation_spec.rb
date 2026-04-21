require 'rails_helper'

RSpec.describe StoryObservation, type: :model do
  let(:account)    { create(:account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account) } }

  describe 'validations' do
    it 'requires observed_on' do
      ActsAsTenant.with_tenant(account) do
        obs = build(:story_observation, account: account, competitor: competitor,
          observed_on: nil)
        expect(obs).not_to be_valid
        expect(obs.errors[:observed_on]).not_to be_empty
      end
    end

    it 'validates format inclusion when present' do
      ActsAsTenant.with_tenant(account) do
        obs = build(:story_observation, account: account, competitor: competitor,
          format: 'invalid_format')
        expect(obs).not_to be_valid
        expect(obs.errors[:format]).not_to be_empty
      end
    end

    it 'allows nil format' do
      ActsAsTenant.with_tenant(account) do
        obs = build(:story_observation, account: account, competitor: competitor, format: nil)
        expect(obs).to be_valid
      end
    end

    it 'validates perceived_engagement inclusion when present' do
      ActsAsTenant.with_tenant(account) do
        obs = build(:story_observation, account: account, competitor: competitor,
          perceived_engagement: 'extreme')
        expect(obs).not_to be_valid
        expect(obs.errors[:perceived_engagement]).not_to be_empty
      end
    end

    it 'allows nil perceived_engagement' do
      ActsAsTenant.with_tenant(account) do
        obs = build(:story_observation, account: account, competitor: competitor,
          perceived_engagement: nil)
        expect(obs).to be_valid
      end
    end

    it 'accepts all valid formats' do
      ActsAsTenant.with_tenant(account) do
        StoryObservation::FORMATS.each do |fmt|
          obs = build(:story_observation, account: account, competitor: competitor, format: fmt)
          expect(obs).to be_valid, "expected format '#{fmt}' to be valid"
        end
      end
    end

    it 'accepts all valid perceived_engagement values' do
      ActsAsTenant.with_tenant(account) do
        StoryObservation::PERCEIVED_ENGAGEMENTS.each do |pe|
          obs = build(:story_observation, account: account, competitor: competitor,
            perceived_engagement: pe)
          expect(obs).to be_valid, "expected perceived_engagement '#{pe}' to be valid"
        end
      end
    end
  end
end
