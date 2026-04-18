require 'rails_helper'

RSpec.describe 'FactoryBot', type: :model do
  it 'all factories are valid' do
    account = create(:account, name: 'lint_tenant')
    ActsAsTenant.with_tenant(account) do
      expect { FactoryBot.lint traits: true }.not_to raise_error
    end
  end
end
