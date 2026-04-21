require 'rails_helper'

RSpec.describe OwnProfiles::Result do
  describe '.success' do
    subject(:result) { described_class.success(data: { count: 3 }) }

    it { is_expected.to be_success }
    it { is_expected.not_to be_failure }

    it 'exposes data' do
      expect(result.data).to eq({ count: 3 })
    end

    it 'has nil error' do
      expect(result.error).to be_nil
    end
  end

  describe '.failure' do
    subject(:result) { described_class.failure(error: 'Token inválido', error_code: :auth_error) }

    it { is_expected.to be_failure }
    it { is_expected.not_to be_success }

    it 'exposes error' do
      expect(result.error).to eq('Token inválido')
    end

    it 'exposes error_code' do
      expect(result.error_code).to eq(:auth_error)
    end
  end
end
