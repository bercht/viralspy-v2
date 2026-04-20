require "rails_helper"

RSpec.describe PromptTemplate do
  describe "validations" do
    it "requires use_case, version, system_content, user_content_erb" do
      template = described_class.new
      expect(template).not_to be_valid
      expect(template.errors[:use_case]).to be_present
      expect(template.errors[:version]).to be_present
      expect(template.errors[:system_content]).to be_present
      expect(template.errors[:user_content_erb]).to be_present
    end

    it "validates use_case inclusion" do
      template = build(:prompt_template, use_case: "invalid_case")
      expect(template).not_to be_valid
      expect(template.errors[:use_case]).to be_present
    end

    it "enforces unique version per use_case" do
      create(:prompt_template, use_case: "reel_analysis", version: 1)
      dup = build(:prompt_template, use_case: "reel_analysis", version: 1)
      expect(dup).not_to be_valid
    end

    it "allows only one active template per use_case" do
      create(:prompt_template, :active, use_case: "reel_analysis", version: 1)
      second = build(:prompt_template, :active, use_case: "reel_analysis", version: 2)
      expect(second).not_to be_valid
      expect(second.errors[:active]).to be_present
    end

    it "allows same version number across different use_cases" do
      create(:prompt_template, use_case: "reel_analysis", version: 1)
      other = build(:prompt_template, use_case: "carousel_analysis", version: 1)
      expect(other).to be_valid
    end
  end

  describe ".fetch_active" do
    it "returns the active template for a use_case" do
      active = create(:prompt_template, :active, use_case: "reel_analysis", version: 1)
      create(:prompt_template, use_case: "reel_analysis", version: 2, active: false)

      expect(described_class.fetch_active(use_case: "reel_analysis")).to eq(active)
    end

    it "raises when no active template exists" do
      create(:prompt_template, use_case: "reel_analysis", version: 1, active: false)

      expect { described_class.fetch_active(use_case: "reel_analysis") }
        .to raise_error(PromptTemplate::MissingActiveTemplateError)
    end
  end

  describe "#render" do
    it "returns system content as-is and user content rendered with locals" do
      template = create(:prompt_template,
        system_content: "System prompt static",
        user_content_erb: "You have <%= count %> posts"
      )

      result = template.render(count: 5)
      expect(result[:system]).to eq("System prompt static")
      expect(result[:user]).to eq("You have 5 posts")
    end

    it "supports trim_mode for cleaner ERB" do
      template = create(:prompt_template,
        user_content_erb: "<% 3.times do |i| -%>line <%= i %>\n<% end -%>"
      )

      result = template.render
      expect(result[:user]).to eq("line 0\nline 1\nline 2\n")
    end
  end
end
