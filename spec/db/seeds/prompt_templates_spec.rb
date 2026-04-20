require "rails_helper"

RSpec.describe "db/seeds/prompt_templates" do
  it "seeds all 4 use cases with active v1 templates" do
    load Rails.root.join("db/seeds/prompt_templates.rb")

    PromptTemplate::USE_CASES.each do |uc|
      active = PromptTemplate.active.find_by(use_case: uc)
      expect(active).to be_present, "Missing active template for #{uc}"
      expect(active.version).to eq(1)
      expect(active.system_content).to be_present
      expect(active.user_content_erb).to be_present
    end
  end

  it "is idempotent (running twice does not duplicate)" do
    2.times { load Rails.root.join("db/seeds/prompt_templates.rb") }

    PromptTemplate::USE_CASES.each do |uc|
      expect(PromptTemplate.where(use_case: uc).count).to eq(1)
    end
  end
end
