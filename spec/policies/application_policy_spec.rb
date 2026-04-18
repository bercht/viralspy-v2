require 'rails_helper'

RSpec.describe ApplicationPolicy, type: :policy do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:record) { double('record') }
  subject { described_class.new(user, record) }

  describe 'default permissions' do
    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_new }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_destroy }
  end
end
