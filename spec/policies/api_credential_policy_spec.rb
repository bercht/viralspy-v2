require "rails_helper"

RSpec.describe ApiCredentialPolicy, type: :policy do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:other_account) { create(:account) }
  let(:other_user) { create(:user, account: other_account) }

  let(:own_credential) do
    ActsAsTenant.with_tenant(account) do
      create(:api_credential, account: account, provider: "openai")
    end
  end

  let(:other_credential) do
    ActsAsTenant.with_tenant(other_account) do
      create(:api_credential, account: other_account, provider: "openai")
    end
  end

  subject { described_class }

  describe "#show?" do
    it "permite ao dono da account" do
      expect(subject.new(user, own_credential).show?).to be true
    end

    it "nega para usuário de outra account" do
      expect(subject.new(other_user, own_credential).show?).to be false
    end
  end

  describe "#create?" do
    it "permite a usuário autenticado" do
      new_cred = ApiCredential.new(account: account)
      expect(subject.new(user, new_cred).create?).to be true
    end
  end

  describe "#update?" do
    it "permite ao dono da account" do
      expect(subject.new(user, own_credential).update?).to be true
    end

    it "nega para usuário de outra account" do
      expect(subject.new(other_user, own_credential).update?).to be false
    end
  end

  describe "#destroy?" do
    it "permite ao dono da account" do
      expect(subject.new(user, own_credential).destroy?).to be true
    end

    it "nega para usuário de outra account" do
      expect(subject.new(other_user, own_credential).destroy?).to be false
    end
  end
end
