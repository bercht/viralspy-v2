require "rails_helper"

RSpec.describe Analyses::GenerateSuggestionsStep do
  let(:account) { create(:account) }
  let(:competitor) { create(:competitor, account: account, instagram_handle: "testcorretor", followers_count: 5000) }

  let(:full_insights) do
    {
      "reels" => { "hooks" => ["Gancho 1"], "structures" => ["S1"], "ctas" => ["CTA1"], "themes" => ["T1"], "observations" => "obs" },
      "carousels" => { "structures" => ["S1"], "content_types" => ["educacional"], "themes" => ["T1"], "observations" => "obs" },
      "images" => { "caption_styles" => ["informativo"], "visual_elements" => ["preço"], "themes" => ["T1"], "observations" => "obs" }
    }
  end

  let(:analysis) do
    create(:analysis, account: account, competitor: competitor,
                      status: :generating_suggestions,
                      profile_metrics: { "posts_per_week" => 4.2 },
                      insights: full_insights)
  end

  def suggestion_payload(n)
    {
      "position" => n,
      "content_type" => n <= 2 ? "reel" : (n <= 4 ? "carousel" : "image"),
      "hook" => "Hook #{n}",
      "caption_draft" => "Caption draft número #{n} com conteúdo relevante.",
      "format_details" => n <= 2 ? { "duration_seconds" => 30, "structure" => ["hook", "cta"] } :
                           (n <= 4 ? { "slides" => [{ "title" => "Slide 1", "body" => "Corpo do slide" }] } :
                                     { "composition_tips" => "foto ampla", "text_overlay" => nil }),
      "suggested_hashtags" => ["imoveis", "corretor"],
      "rationale" => "Funciona porque segue padrão do concorrente."
    }
  end

  let(:five_suggestions_json) do
    JSON.generate("suggestions" => (1..5).map { |n| suggestion_payload(n) })
  end

  def mock_llm_response(json)
    instance_double(LLM::Response, parsed_json: JSON.parse(json), content: json)
  end

  describe ".call" do
    context "happy path — all 3 insight types available" do
      let!(:anthropic_cred) do
        create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test")
      end

      before do
        allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))
      end

      it "creates 5 ContentSuggestions and marks analysis completed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(result.data[:count]).to eq(5)
          reloaded = analysis.reload
          expect(reloaded.status).to eq("completed")
          expect(reloaded.finished_at).to be_present
          expect(reloaded.content_suggestions.count).to eq(5)
        end
      end

      it "calls LLM with anthropic provider and claude-sonnet-4-6 model" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(LLM::Gateway).to have_received(:complete).with(
            hash_including(provider: :anthropic, model: "claude-sonnet-4-6", json_mode: true)
          )
        end
      end

      it "passes api_key from credential to Gateway" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(LLM::Gateway).to have_received(:complete)
            .with(hash_including(api_key: "sk-ant-test"))
        end
      end

      it "persists ContentSuggestions with correct attributes" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          suggestion = analysis.content_suggestions.find_by(position: 1)
          expect(suggestion.content_reel?).to be true
          expect(suggestion.hook).to eq("Hook 1")
          expect(suggestion.caption_draft).to include("Caption draft")
          expect(suggestion.suggested_hashtags).to include("imoveis")
          expect(suggestion.rationale).to be_present
          expect(suggestion.draft?).to be true
        end
      end
    end

    context "insights only from reels" do
      let!(:anthropic_cred) { create(:api_credential, :anthropic, account: account) }
      let(:analysis) do
        create(:analysis, account: account, competitor: competitor,
                          status: :generating_suggestions,
                          profile_metrics: {},
                          insights: { "reels" => full_insights["reels"] })
      end

      before do
        allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))
      end

      it "uses fallback mix of 5 reels and succeeds" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(result.data[:mix]).to eq({ reel: 5, carousel: 0, image: 0 })
        end
      end
    end

    context "insights from reels and carousels only" do
      let!(:anthropic_cred) { create(:api_credential, :anthropic, account: account) }
      let(:analysis) do
        create(:analysis, account: account, competitor: competitor,
                          status: :generating_suggestions,
                          profile_metrics: {},
                          insights: { "reels" => full_insights["reels"], "carousels" => full_insights["carousels"] })
      end

      before do
        allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))
      end

      it "uses mix of 3 reels + 2 carousels (reel absorbs image slot)" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(result.data[:mix]).to eq({ reel: 3, carousel: 2, image: 0 })
        end
      end
    end

    context "insights from carousels only" do
      let!(:anthropic_cred) { create(:api_credential, :anthropic, account: account) }
      let(:analysis) do
        create(:analysis, account: account, competitor: competitor,
                          status: :generating_suggestions,
                          profile_metrics: {},
                          insights: { "carousels" => full_insights["carousels"] })
      end

      before do
        allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))
      end

      it "uses fallback mix of 5 carousels" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(result.data[:mix]).to eq({ reel: 0, carousel: 5, image: 0 })
        end
      end
    end

    context "no insights available" do
      let(:analysis) do
        create(:analysis, account: account, competitor: competitor,
                          status: :generating_suggestions, insights: {})
      end

      it "returns :no_insights failure and marks analysis failed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:no_insights)
          expect(analysis.reload.status).to eq("failed")
          expect(analysis.reload.finished_at).to be_present
        end
      end
    end

    context "LLM returns invalid JSON" do
      let!(:anthropic_cred) { create(:api_credential, :anthropic, account: account) }

      before do
        bad_response = instance_double(LLM::Response)
        allow(bad_response).to receive(:parsed_json).and_raise(LLM::ResponseParseError, "unexpected token")
        allow(LLM::Gateway).to receive(:complete).and_return(bad_response)
      end

      it "returns :invalid_json failure and marks analysis failed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:invalid_json)
          expect(analysis.reload.status).to eq("failed")
        end
      end
    end

    context "LLM returns valid JSON with empty suggestions array" do
      let!(:anthropic_cred) { create(:api_credential, :anthropic, account: account) }

      before do
        allow(LLM::Gateway).to receive(:complete)
          .and_return(mock_llm_response(JSON.generate("suggestions" => [])))
      end

      it "returns :empty_suggestions failure" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:empty_suggestions)
          expect(analysis.reload.status).to eq("failed")
        end
      end
    end

    context "LLM returns only 3 suggestions (less than 5)" do
      let!(:anthropic_cred) { create(:api_credential, :anthropic, account: account) }

      let(:three_suggestions_json) do
        JSON.generate("suggestions" => (1..3).map { |n| suggestion_payload(n) })
      end

      before do
        allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(three_suggestions_json))
      end

      it "persists 3 suggestions and marks analysis completed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(result.data[:count]).to eq(3)
          expect(analysis.reload.content_suggestions.count).to eq(3)
          expect(analysis.reload.status).to eq("completed")
        end
      end
    end

    context "when credential for generation_provider (anthropic) is missing" do
      before { allow(LLM::Gateway).to receive(:complete) }

      it "marks analysis failed without calling LLM" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(analysis.reload.status).to eq("failed")
          expect(LLM::Gateway).not_to have_received(:complete)
        end
      end
    end

    context "when credential for generation_provider is inactive" do
      before do
        create(:api_credential, :anthropic, :inactive, account: account)
        allow(LLM::Gateway).to receive(:complete)
      end

      it "treats inactive credential as missing, marks analysis failed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(analysis.reload.status).to eq("failed")
          expect(LLM::Gateway).not_to have_received(:complete)
        end
      end
    end

    context "when generation_provider preference is overridden to openai" do
      let!(:openai_cred) do
        create(:api_credential, :openai, account: account, encrypted_api_key: "sk-test-openai")
      end

      before do
        account.update!(llm_preferences: { "generation_provider" => "openai", "generation_model" => "gpt-4o" })
        allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))
      end

      it "uses openai provider and gpt-4o model from custom preferences" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(LLM::Gateway).to have_received(:complete)
            .with(hash_including(provider: :openai, model: "gpt-4o", api_key: "sk-test-openai"))
        end
      end
    end
  end

  describe "private resolution methods" do
    let(:step) { described_class.new(analysis) }

    it "provider_for reads generation_provider from account preferences (default: anthropic)" do
      expect(step.send(:provider_for, "content_suggestions")).to eq(:anthropic)
    end

    it "model_for reads generation_model from account preferences (default: claude-sonnet-4-6)" do
      expect(step.send(:model_for, "content_suggestions")).to eq("claude-sonnet-4-6")
    end

    it "api_key_for returns encrypted_api_key from active credential" do
      create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-from-credential")
      expect(step.send(:api_key_for, :anthropic)).to eq("sk-ant-from-credential")
    end

    it "api_key_for raises NotConfiguredError when credential is missing" do
      expect { step.send(:api_key_for, :anthropic) }
        .to raise_error(ApiCredentials::NotConfiguredError, /No active API credential/)
    end

    it "api_key_for raises NotConfiguredError when credential is inactive" do
      create(:api_credential, :anthropic, :inactive, account: account)
      expect { step.send(:api_key_for, :anthropic) }
        .to raise_error(ApiCredentials::NotConfiguredError)
    end
  end

  describe "resolve_mix (private)" do
    let(:step) { described_class.new(analysis) }

    def resolve(available)
      step.send(:resolve_mix, available)
    end

    it "returns 2+2+1 when all 3 types available" do
      expect(resolve(%i[reel carousel image])).to eq({ reel: 2, carousel: 2, image: 1 })
    end

    it "reel absorbs image slot when image unavailable" do
      expect(resolve(%i[reel carousel])).to eq({ reel: 3, carousel: 2, image: 0 })
    end

    it "reel gets all 5 when only reel available" do
      expect(resolve([:reel])).to eq({ reel: 5, carousel: 0, image: 0 })
    end

    it "carousel gets all 5 when only carousel available" do
      expect(resolve([:carousel])).to eq({ reel: 0, carousel: 5, image: 0 })
    end

    it "image gets all 5 when only image available" do
      expect(resolve([:image])).to eq({ reel: 0, carousel: 0, image: 5 })
    end
  end

  describe "author_role and target_audience propagation" do
    let!(:anthropic_cred) { create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test") }

    it "passes author_role and target_audience to PromptRenderer when first playbook has them" do
      playbook = ActsAsTenant.with_tenant(account) do
        create(:playbook, account: account, author_role: "Especialista em marketing imobiliário", target_audience: "Corretores de imóveis")
      end
      ActsAsTenant.with_tenant(account) do
        create(:analysis_playbook, analysis: analysis, playbook: playbook)
      end

      captured_locals = []
      allow(Analyses::PromptRenderer).to receive(:render) do |**kwargs|
        captured_locals << kwargs[:locals]
        "mocked prompt"
      end
      allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))

      ActsAsTenant.with_tenant(account) { described_class.call(analysis) }

      expect(captured_locals).to all(include(
        author_role: "Especialista em marketing imobiliário",
        target_audience: "Corretores de imóveis"
      ))
    end

    it "passes nil author_role and target_audience when analysis has no associated playbooks" do
      captured_locals = []
      allow(Analyses::PromptRenderer).to receive(:render) do |**kwargs|
        captured_locals << kwargs[:locals]
        "mocked prompt"
      end
      allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))

      ActsAsTenant.with_tenant(account) { described_class.call(analysis) }

      expect(captured_locals).to all(include(author_role: nil, target_audience: nil))
    end
  end

  describe "niche propagation" do
    let!(:anthropic_cred) { create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test") }

    it "passes competitor_niche to PromptRenderer when competitor has a niche" do
      niche_competitor = create(:competitor, account: account, instagram_handle: "nutritionista2", niche: "Nutrição funcional", followers_count: 10_000)
      niche_analysis = create(:analysis, account: account, competitor: niche_competitor,
                                         status: :generating_suggestions, insights: full_insights,
                                         profile_metrics: { "posts_per_week" => 3.0 })

      captured_locals = []
      allow(Analyses::PromptRenderer).to receive(:render) do |**kwargs|
        captured_locals << kwargs[:locals]
        "mocked prompt"
      end
      allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))

      ActsAsTenant.with_tenant(account) do
        described_class.call(niche_analysis)
      end

      expect(captured_locals).to all(include(competitor_niche: "Nutrição funcional"))
    end

    it "uses neutral fallback when competitor has no niche and no playbook" do
      no_niche_competitor = create(:competitor, account: account, instagram_handle: "semnicho2", niche: nil, followers_count: 5_000)
      no_niche_analysis = create(:analysis, account: account, competitor: no_niche_competitor,
                                            status: :generating_suggestions, insights: full_insights,
                                            profile_metrics: { "posts_per_week" => 2.0 })

      captured_locals = []
      allow(Analyses::PromptRenderer).to receive(:render) do |**kwargs|
        captured_locals << kwargs[:locals]
        "mocked prompt"
      end
      allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(five_suggestions_json))

      ActsAsTenant.with_tenant(account) do
        described_class.call(no_niche_analysis)
      end

      expect(captured_locals).to all(include(competitor_niche: "conteúdo de Instagram em português brasileiro"))
    end
  end
end
