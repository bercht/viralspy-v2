require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe '#full_name' do
    context 'when first_name and last_name are present' do
      it 'returns full name' do
        user = build(:user, first_name: 'João', last_name: 'Silva')
        expect(user.full_name).to eq('João Silva')
      end
    end

    context 'when both names are blank' do
      it 'falls back to email' do
        user = build(:user, first_name: '', last_name: '', email: 'joao@test.com')
        expect(user.full_name).to eq('joao@test.com')
      end
    end
  end
end
