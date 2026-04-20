require "rails_helper"

RSpec.describe PlaybookVersion, type: :model do
  let(:account) { create(:account) }

  describe "validations" do
    it "requires content" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        version = build(:playbook_version, playbook: playbook, content: nil)
        expect(version).not_to be_valid
        expect(version.errors[:content]).to be_present
      end
    end

    it "requires version_number" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        version = build(:playbook_version, playbook: playbook, version_number: nil)
        expect(version).not_to be_valid
      end
    end

    it "requires unique version_number per playbook" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        create(:playbook_version, playbook: playbook, version_number: 1)
        duplicate = build(:playbook_version, playbook: playbook, version_number: 1)
        expect(duplicate).not_to be_valid
      end
    end
  end

  describe "scopes" do
    it ".recent returns versions ordered by version_number desc" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        v1 = create(:playbook_version, playbook: playbook, version_number: 1)
        v2 = create(:playbook_version, playbook: playbook, version_number: 2)
        expect(PlaybookVersion.recent.first).to eq(v2)
        expect(PlaybookVersion.recent.last).to eq(v1)
      end
    end
  end

  describe "associations" do
    it "belongs to playbook" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        version = create(:playbook_version, playbook: playbook)
        expect(version.playbook).to eq(playbook)
      end
    end
  end
end
