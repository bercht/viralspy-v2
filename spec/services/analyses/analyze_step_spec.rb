require "rails_helper"

RSpec.describe Analyses::AnalyzeStep do
  let(:account) { create(:account) }
  let(:competitor) { create(:competitor, account: account, instagram_handle: "testcorretor", followers_count: 5000) }
  let(:analysis) do
    create(:analysis, account: account, competitor: competitor, status: :analyzing,
                      profile_metrics: { "posts_per_week" => 4.2, "avg_engagement_rate" => 0.05, "content_mix" => {} })
  end

  def create_selected_post(type, **opts)
    traits = [type, :selected]
    create(:post, *traits, account: account, analysis: analysis, competitor: competitor,
                           posted_at: 3.days.ago, **opts)
  end

  let(:reel_insights_json) do
    JSON.generate(
      hooks: ["Gancho 1", "Gancho 2", "Gancho 3"],
      structures: ["Hook → Problema → Solução → CTA"],
      ctas: ["Me chama no direct"],
      themes: ["avaliação", "precificação"],
      observations: "Perfil foca em conteúdo educacional para corretores. Tom direto e objetivo."
    )
  end

  let(:carousel_insights_json) do
    JSON.generate(
      structures: ["Slide gancho → desenvolvimento → CTA"],
      content_types: ["educacional", "checklist"],
      themes: ["documentação", "financiamento"],
      observations: "Carrosséis focam em checklist e conteúdo informativo. Alta taxa de salvamentos."
    )
  end

  let(:image_insights_json) do
    JSON.generate(
      caption_styles: ["informativo", "comercial"],
      visual_elements: ["preço na imagem", "localização"],
      themes: ["lançamentos", "imóveis prontos"],
      observations: "Imagens com preço visível têm maior engajamento. Composição simples funciona."
    )
  end

  def mock_llm_response(json_content)
    instance_double(LLM::Response, parsed_json: JSON.parse(json_content), content: json_content)
  end

  describe ".call" do
    context "sets :analyzing status on entry" do
      let!(:openai_cred) { create(:api_credential, :openai, account: account, encrypted_api_key: "sk-test-openai") }

      it "sets analysis status to :analyzing before calling LLM" do
        analysis.update!(status: :transcribing)
        captured_status = nil

        allow(LLM::Gateway).to receive(:complete) do |**_kwargs|
          captured_status ||= analysis.reload.status
          mock_llm_response(reel_insights_json)
        end

        ActsAsTenant.with_tenant(account) do
          create_selected_post(:reel)
          described_class.call(analysis)
        end

        expect(captured_status).to eq("analyzing")
      end
    end

    context "happy path — posts of all 3 types selected" do
      let!(:openai_cred) { create(:api_credential, :openai, account: account, encrypted_api_key: "sk-test-openai") }
      let!(:reel) { create_selected_post(:reel) }
      let!(:carousel) { create_selected_post(:carousel) }
      let!(:image) { create_selected_post(:image) }

      before do
        allow(LLM::Gateway).to receive(:complete)
          .with(hash_including(use_case: "reel_analysis"))
          .and_return(mock_llm_response(reel_insights_json))
        allow(LLM::Gateway).to receive(:complete)
          .with(hash_including(use_case: "carousel_analysis"))
          .and_return(mock_llm_response(carousel_insights_json))
        allow(LLM::Gateway).to receive(:complete)
          .with(hash_including(use_case: "image_analysis"))
          .and_return(mock_llm_response(image_insights_json))
      end

      it "returns success and saves insights with all 3 keys" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          reloaded = analysis.reload
          expect(reloaded.status).to eq("generating_suggestions")
          expect(reloaded.insights.keys).to include("reels", "carousels", "images")
          expect(reloaded.insights["reels"]["hooks"]).to be_a(Array)
        end
      end

      it "calls LLM with openai provider and gpt-4o-mini model" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(LLM::Gateway).to have_received(:complete)
            .with(hash_including(provider: :openai, model: "gpt-4o-mini", json_mode: true))
            .at_least(3).times
        end
      end

      it "passes api_key from credential to Gateway" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(LLM::Gateway).to have_received(:complete)
            .with(hash_including(api_key: "sk-test-openai"))
            .at_least(3).times
        end
      end
    end

    context "profile with only reels" do
      let!(:openai_cred) { create(:api_credential, :openai, account: account, encrypted_api_key: "sk-test-openai") }
      let!(:reel) { create_selected_post(:reel) }

      before do
        allow(LLM::Gateway).to receive(:complete)
          .with(hash_including(use_case: "reel_analysis"))
          .and_return(mock_llm_response(reel_insights_json))
      end

      it "skips carousel/image calls and saves only reels insights" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(analysis.reload.insights.keys).to eq(["reels"])
          expect(analysis.reload.status).to eq("generating_suggestions")
          expect(LLM::Gateway).to have_received(:complete).once
        end
      end
    end

    context "one type fails with invalid JSON" do
      let!(:openai_cred) { create(:api_credential, :openai, account: account, encrypted_api_key: "sk-test-openai") }
      let!(:reel) { create_selected_post(:reel) }
      let!(:carousel) { create_selected_post(:carousel) }

      before do
        allow(LLM::Gateway).to receive(:complete)
          .with(hash_including(use_case: "reel_analysis"))
          .and_return(mock_llm_response(reel_insights_json))
        bad_response = instance_double(LLM::Response)
        allow(bad_response).to receive(:parsed_json).and_raise(LLM::ResponseParseError, "invalid JSON")
        allow(LLM::Gateway).to receive(:complete)
          .with(hash_including(use_case: "carousel_analysis"))
          .and_return(bad_response)
      end

      it "continues pipeline with partial insights" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          reloaded = analysis.reload
          expect(reloaded.status).to eq("generating_suggestions")
          expect(reloaded.insights.keys).to eq(["reels"])
          expect(result.data[:failures]).to include(a_string_matching(/carousel/))
        end
      end
    end

    context "all types fail with LLM error" do
      let!(:openai_cred) { create(:api_credential, :openai, account: account, encrypted_api_key: "sk-test-openai") }
      let!(:reel) { create_selected_post(:reel) }
      let!(:carousel) { create_selected_post(:carousel) }

      before do
        bad_response = instance_double(LLM::Response)
        allow(bad_response).to receive(:parsed_json).and_raise(LLM::RateLimitError, "rate limit")
        allow(LLM::Gateway).to receive(:complete).and_return(bad_response)
      end

      it "returns failure and marks analysis as failed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:analyze_all_failed)
          expect(analysis.reload.status).to eq("failed")
          expect(analysis.reload.finished_at).to be_present
        end
      end
    end

    context "no selected posts at all" do
      before { allow(LLM::Gateway).to receive(:complete) }

      it "returns success with empty insights and advances status" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(LLM::Gateway).not_to have_received(:complete)
          expect(analysis.reload.status).to eq("generating_suggestions")
        end
      end
    end

    context "all selected types fail via exception in analyze_type" do
      before do
        create_selected_post(:reel)
        allow(Analyses::PromptRenderer).to receive(:render).and_raise(ArgumentError, "Prompt not found")
      end

      it "returns :analyze_all_failed and marks analysis failed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:analyze_all_failed)
          expect(analysis.reload.status).to eq("failed")
          expect(analysis.reload.finished_at).to be_present
        end
      end
    end

    context "when credential for analysis_provider (openai) is missing" do
      let!(:reel) { create_selected_post(:reel) }

      before { allow(LLM::Gateway).to receive(:complete) }

      it "records failure for all types, marks analysis failed, does not call LLM" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:analyze_all_failed)
          expect(analysis.reload.status).to eq("failed")
          expect(LLM::Gateway).not_to have_received(:complete)
        end
      end
    end

    context "when credential for analysis_provider is inactive" do
      let!(:reel) { create_selected_post(:reel) }

      before do
        create(:api_credential, :openai, :inactive, account: account)
        allow(LLM::Gateway).to receive(:complete)
      end

      it "treats inactive credential as missing, marks analysis failed" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_failure
          expect(result.error_code).to eq(:analyze_all_failed)
          expect(analysis.reload.status).to eq("failed")
          expect(LLM::Gateway).not_to have_received(:complete)
        end
      end
    end

    context "when analysis_provider preference is overridden to anthropic" do
      let!(:anthropic_cred) do
        create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test")
      end
      let!(:reel) { create_selected_post(:reel) }

      before do
        account.update!(llm_preferences: { "analysis_provider" => "anthropic", "analysis_model" => "claude-sonnet-4-6" })
        allow(LLM::Gateway).to receive(:complete)
          .with(hash_including(use_case: "reel_analysis"))
          .and_return(mock_llm_response(reel_insights_json))
      end

      it "uses anthropic provider and claude-sonnet-4-6 model from preferences" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(analysis)

          expect(result).to be_success
          expect(LLM::Gateway).to have_received(:complete)
            .with(hash_including(provider: :anthropic, model: "claude-sonnet-4-6", api_key: "sk-ant-test"))
        end
      end
    end
  end

  describe "private resolution methods" do
    let(:step) { described_class.new(analysis) }

    it "provider_for reads analysis_provider from account preferences (default: openai)" do
      expect(step.send(:provider_for, "reel_analysis")).to eq(:openai)
    end

    it "model_for reads analysis_model from account preferences (default: gpt-4o-mini)" do
      expect(step.send(:model_for, "reel_analysis")).to eq("gpt-4o-mini")
    end

    it "api_key_for returns encrypted_api_key from active credential" do
      create(:api_credential, :openai, account: account, encrypted_api_key: "sk-from-credential")
      expect(step.send(:api_key_for, :openai)).to eq("sk-from-credential")
    end

    it "api_key_for raises NotConfiguredError when credential is missing" do
      expect { step.send(:api_key_for, :openai) }
        .to raise_error(ApiCredentials::NotConfiguredError, /No active API credential/)
    end

    it "api_key_for raises NotConfiguredError when credential is inactive" do
      create(:api_credential, :openai, :inactive, account: account)
      expect { step.send(:api_key_for, :openai) }
        .to raise_error(ApiCredentials::NotConfiguredError)
    end

    context "when account has custom preferences" do
      before { account.update!(llm_preferences: { "analysis_provider" => "anthropic", "analysis_model" => "claude-opus-4-7" }) }

      it "provider_for returns the custom provider as symbol" do
        expect(step.send(:provider_for, "reel_analysis")).to eq(:anthropic)
      end

      it "model_for returns the custom model" do
        expect(step.send(:model_for, "reel_analysis")).to eq("claude-opus-4-7")
      end
    end
  end

  describe "niche propagation" do
    let!(:openai_cred) { create(:api_credential, :openai, account: account, encrypted_api_key: "sk-test-openai") }

    it "passes competitor_niche to PromptRenderer when competitor has a niche" do
      niche_competitor = create(:competitor, account: account, instagram_handle: "nutritionista", niche: "Nutrição funcional", followers_count: 10_000)
      niche_analysis = create(:analysis, account: account, competitor: niche_competitor, status: :analyzing,
                                         profile_metrics: { "posts_per_week" => 3.0, "avg_engagement_rate" => 0.04, "content_mix" => {} })

      captured_locals = []
      allow(Analyses::PromptRenderer).to receive(:render) do |**kwargs|
        captured_locals << kwargs[:locals]
        "mocked prompt"
      end
      allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(reel_insights_json))

      ActsAsTenant.with_tenant(account) do
        create(:post, :reel, :selected, account: account, analysis: niche_analysis, competitor: niche_competitor, posted_at: 3.days.ago)
        described_class.call(niche_analysis)
      end

      expect(captured_locals).to all(include(competitor_niche: "Nutrição funcional"))
    end

    it "uses neutral fallback when competitor has no niche and no playbook" do
      no_niche_competitor = create(:competitor, account: account, instagram_handle: "semnicho", niche: nil, followers_count: 5_000)
      no_niche_analysis = create(:analysis, account: account, competitor: no_niche_competitor, status: :analyzing,
                                            profile_metrics: { "posts_per_week" => 2.0, "avg_engagement_rate" => 0.03, "content_mix" => {} })

      captured_locals = []
      allow(Analyses::PromptRenderer).to receive(:render) do |**kwargs|
        captured_locals << kwargs[:locals]
        "mocked prompt"
      end
      allow(LLM::Gateway).to receive(:complete).and_return(mock_llm_response(reel_insights_json))

      ActsAsTenant.with_tenant(account) do
        create(:post, :reel, :selected, account: account, analysis: no_niche_analysis, competitor: no_niche_competitor, posted_at: 3.days.ago)
        described_class.call(no_niche_analysis)
      end

      expect(captured_locals).to all(include(competitor_niche: "conteúdo de Instagram em português brasileiro"))
    end
  end
end
