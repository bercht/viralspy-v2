require "rails_helper"

RSpec.describe ContentSuggestionPolicy, type: :policy do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:competitor) { create(:competitor, account: account) }
  let(:analysis) { create(:analysis, account: account, competitor: competitor) }
  let(:suggestion) { create(:content_suggestion, account: account, analysis: analysis) }
  let(:other_account) { create(:account) }
  let(:other_user) { create(:user, account: other_account) }

  subject { described_class }

  describe "update?" do
    it "permite ao dono da account" do
      expect(subject.new(user, suggestion).update?).to be true
    end

    it "nega para usuário de outra account" do
      expect(subject.new(other_user, suggestion).update?).to be false
    end
  end
end
