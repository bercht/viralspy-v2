require "rails_helper"

RSpec.describe CompetitorPolicy, type: :policy do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) { create(:competitor, account: account) }
  let(:other_account) { create(:account) }
  let(:other_user) { create(:user, account: other_account) }
  let(:other_competitor) { create(:competitor, account: other_account) }

  subject { described_class }

  describe "show?" do
    it "permite ao dono da account" do
      expect(subject.new(user, competitor).show?).to be true
    end

    it "nega para usuário de outra account" do
      expect(subject.new(other_user, competitor).show?).to be false
    end
  end

  describe "create?" do
    it "permite a qualquer usuário autenticado" do
      new_competitor = Competitor.new(account: account)
      expect(subject.new(user, new_competitor).create?).to be true
    end
  end

  describe "new?" do
    it "delega para create?" do
      new_competitor = Competitor.new(account: account)
      expect(subject.new(user, new_competitor).new?).to be true
    end
  end

  describe "destroy?" do
    it "permite ao dono da account" do
      expect(subject.new(user, competitor).destroy?).to be true
    end

    it "nega para usuário de outra account" do
      expect(subject.new(other_user, competitor).destroy?).to be false
    end
  end

  describe "update?" do
    it "permite ao dono da account" do
      expect(subject.new(user, competitor).update?).to be true
    end

    it "nega para usuário de outra account" do
      expect(subject.new(other_user, competitor).update?).to be false
    end
  end
end
