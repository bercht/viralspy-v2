require "rails_helper"

RSpec.describe Analyses::PromptRenderer do
  describe ".render" do
    context "with a real prompt template" do
      let(:account) { create(:account) }
      let(:competitor) { create(:competitor, account: account, instagram_handle: "testcorretor", followers_count: 5000) }
      let(:analysis) { create(:analysis, account: account, competitor: competitor) }
      let(:posts) do
        ActsAsTenant.with_tenant(account) do
          [create(:post, :reel, :selected, account: account, analysis: analysis, competitor: competitor,
                                           caption: "Dicas de imóveis", posted_at: 3.days.ago)]
        end
      end
      let(:locals) do
        {
          handle: competitor.instagram_handle,
          followers: competitor.followers_count,
          profile_metrics: { "posts_per_week" => 4.2, "avg_engagement_rate" => 0.05, "content_mix" => {} },
          posts: posts,
          competitor_niche: "Mercado imobiliário"
        }
      end

      it "renders analyze_reels system prompt without error" do
        result = described_class.render(step: "analyze_reels", kind: :system, locals: locals)
        expect(result).to be_a(String)
        expect(result).not_to be_empty
        expect(result).to include("Mercado imobiliário")
      end

      it "renders analyze_reels user prompt substituting handle and followers" do
        result = described_class.render(step: "analyze_reels", kind: :user, locals: locals)
        expect(result).to include("testcorretor")
        expect(result).to include("5000")
      end

      it "renders analyze_carousels system prompt" do
        result = described_class.render(step: "analyze_carousels", kind: :system, locals: locals)
        expect(result).to be_a(String)
        expect(result).not_to be_empty
      end

      it "renders analyze_carousels user prompt" do
        result = described_class.render(step: "analyze_carousels", kind: :user, locals: locals)
        expect(result).to include("testcorretor")
      end

      it "renders analyze_images system prompt" do
        result = described_class.render(step: "analyze_images", kind: :system, locals: locals)
        expect(result).to be_a(String)
        expect(result).not_to be_empty
      end

      it "renders analyze_images user prompt" do
        result = described_class.render(step: "analyze_images", kind: :user, locals: locals)
        expect(result).to include("testcorretor")
      end

      it "renders generate_suggestions system prompt with target_count and mix_label" do
        gen_locals = {
          handle: competitor.instagram_handle,
          followers: competitor.followers_count,
          profile_metrics: {},
          insights: {},
          target_count: 5,
          mix_label: "2 reels + 2 carousels + 1 image",
          competitor_niche: "Fitness",
          author_role: nil,
          target_audience: nil
        }
        result = described_class.render(step: "generate_suggestions", kind: :system, locals: gen_locals)
        expect(result).to include("5")
        expect(result).to include("2 reels + 2 carousels + 1 image")
        expect(result).to include("Fitness")
      end

      it "renders generate_suggestions user prompt" do
        gen_locals = {
          handle: competitor.instagram_handle,
          followers: competitor.followers_count,
          profile_metrics: { "posts_per_week" => 3 },
          insights: { "reels" => { "hooks" => ["hook1"] } },
          target_count: 5,
          mix_label: "2 reels + 2 carousels + 1 image",
          competitor_niche: "Fitness"
        }
        result = described_class.render(step: "generate_suggestions", kind: :user, locals: gen_locals)
        expect(result).to include("testcorretor")
        expect(result).to include("5000")
      end
    end

    context "with a missing template" do
      it "raises ArgumentError with informative message" do
        expect {
          described_class.render(step: "nonexistent_step", kind: :system)
        }.to raise_error(ArgumentError, /Prompt not found/)
      end
    end

    context "with locals substitution" do
      it "makes locals available as variables in the template" do
        result = described_class.render(
          step: "generate_suggestions",
          kind: :user,
          locals: { handle: "myhandle", followers: 9999, profile_metrics: {}, insights: {}, target_count: 3, mix_label: "3 reels", competitor_niche: "Marketing digital" }
        )
        expect(result).to include("myhandle")
        expect(result).to include("9999")
        expect(result).to include("3 reels")
      end
    end

    context "rendered output is stripped" do
      it "removes leading and trailing whitespace" do
        result = described_class.render(step: "analyze_reels", kind: :system, locals: { competitor_niche: "Fitness" })
        expect(result).not_to start_with("\n")
        expect(result).not_to end_with("\n")
      end
    end
  end
end
