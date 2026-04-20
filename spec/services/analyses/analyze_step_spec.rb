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

      it "calls LLM with anthropic provider and claude-sonnet-4-5 model" do
        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(LLM::Gateway).to have_received(:complete)
            .with(hash_including(provider: :anthropic, model: "claude-sonnet-4-5", json_mode: true))
            .at_least(3).times
        end
      end

      it "passes api_key resolved from ENV to Gateway" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY").and_return("test-anthropic-key")

        ActsAsTenant.with_tenant(account) do
          described_class.call(analysis)

          expect(LLM::Gateway).to have_received(:complete)
            .with(hash_including(api_key: "test-anthropic-key"))
            .at_least(3).times
        end
      end
    end

    context "profile with only reels" do
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

    context "all types fail" do
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
  end

  describe "private resolution methods" do
    let(:step) { described_class.new(analysis) }

    it "provider_for returns :anthropic" do
      expect(step.send(:provider_for, "reel_analysis")).to eq(:anthropic)
    end

    it "model_for returns claude-sonnet-4-5" do
      expect(step.send(:model_for, "reel_analysis")).to eq("claude-sonnet-4-5")
    end

    it "api_key_for reads ENV for the given provider" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY").and_return("anthro-key")
      expect(step.send(:api_key_for, :anthropic)).to eq("anthro-key")
    end
  end
end
