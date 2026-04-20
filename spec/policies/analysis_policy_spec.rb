require "rails_helper"

RSpec.describe AnalysisPolicy, type: :policy do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) { create(:competitor, account: account) }
  let(:analysis) { create(:analysis, account: account, competitor: competitor) }
  let(:other_account) { create(:account) }
  let(:other_user) { create(:user, account: other_account) }

  subject { described_class }

  describe "show?" do
    it "permite ao dono da account" do
      expect(subject.new(user, analysis).show?).to be true
    end

    it "nega para usuário de outra account" do
      expect(subject.new(other_user, analysis).show?).to be false
    end
  end

  describe "new?" do
    it "permite ao dono da account" do
      new_analysis = Analysis.new(account: account)
      expect(subject.new(user, new_analysis).new?).to be true
    end

    it "nega para usuário de outra account" do
      new_analysis = Analysis.new(account: account)
      expect(subject.new(other_user, new_analysis).new?).to be false
    end
  end

  describe "create?" do
    it "permite ao dono da account" do
      new_analysis = Analysis.new(account: account)
      expect(subject.new(user, new_analysis).create?).to be true
    end

    it "nega para usuário de outra account" do
      new_analysis = Analysis.new(account: account)
      expect(subject.new(other_user, new_analysis).create?).to be false
    end
  end
end
