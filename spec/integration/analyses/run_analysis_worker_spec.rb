require "rails_helper"

# Integration spec: runs the full pipeline with real service objects.
# Only external boundaries are mocked: Scraping::Factory, Transcription::Factory, LLM::Gateway.
RSpec.describe "Analyses::RunAnalysisWorker integration" do
  let(:account) { create(:account, :with_credentials) }
  let(:competitor) do
    create(:competitor, account: account, instagram_handle: "testcorretor", followers_count: 5_000)
  end
  let(:analysis) { create(:analysis, account: account, competitor: competitor, status: :pending, max_posts: 30) }

  # Credentials are created by :with_credentials trait with random keys.
  # Fetch them so we can assert in stubs.
  def openai_key
    ActsAsTenant.with_tenant(account) { account.api_credential_for("openai").encrypted_api_key }
  end

  def anthropic_key
    ActsAsTenant.with_tenant(account) { account.api_credential_for("anthropic").encrypted_api_key }
  end

  def assemblyai_key
    ActsAsTenant.with_tenant(account) { account.api_credential_for("assemblyai").encrypted_api_key }
  end

  # --- Scraping mock ---

  let(:posts_payload) do
    reels = 15.times.map do |i|
      {
        instagram_post_id: "reel_#{i}",
        shortcode: "R#{i}ABC",
        post_type: "reel",
        caption: "Reel #{i} — dicas para avaliar seu imóvel corretamente",
        display_url: "https://cdn.example.com/r#{i}.jpg",
        video_url: "https://cdn.example.com/r#{i}.mp4",
        likes_count: 1_000 - (i * 30),
        comments_count: 100 - (i * 3),
        video_view_count: 5_000 - (i * 100),
        hashtags: %w[imoveis corretor casapropria],
        mentions: [],
        posted_at: (i + 2).days.ago
      }
    end

    carousels = 8.times.map do |i|
      {
        instagram_post_id: "carousel_#{i}",
        shortcode: "C#{i}ABC",
        post_type: "carousel",
        caption: "Carrossel #{i} — checklist para compra segura",
        display_url: "https://cdn.example.com/c#{i}.jpg",
        video_url: nil,
        likes_count: 500 - (i * 20),
        comments_count: 40 - (i * 2),
        video_view_count: nil,
        hashtags: %w[imoveis financiamento],
        mentions: [],
        posted_at: (i + 2).days.ago
      }
    end

    images = 7.times.map do |i|
      {
        instagram_post_id: "image_#{i}",
        shortcode: "I#{i}ABC",
        post_type: "image",
        caption: "Imagem #{i} — apartamento disponível com vista panorâmica",
        display_url: "https://cdn.example.com/i#{i}.jpg",
        video_url: nil,
        likes_count: 200 - (i * 10),
        comments_count: 15 - i,
        video_view_count: nil,
        hashtags: %w[imoveis apartamento],
        mentions: [],
        posted_at: (i + 2).days.ago
      }
    end

    reels + carousels + images
  end

  let(:scraping_result) do
    Scraping::Result.success(
      profile_data: {
        full_name: "Test Corretor",
        bio: "Especialista em imóveis em BH",
        followers_count: 5_000,
        following_count: 300,
        posts_count: 200,
        profile_pic_url: "https://example.com/pic.jpg"
      },
      posts: posts_payload
    )
  end

  def build_llm_response(json, model:, provider:)
    LLM::Response.new(
      content: json,
      raw: {},
      usage: { prompt_tokens: 500, completion_tokens: 300 },
      model: model,
      provider: provider
    )
  end

  # --- Analysis LLM responses ---

  let(:reel_insights_json) do
    JSON.generate(
      hooks: ["3 erros que 80% dos corretores cometem", "O imóvel que ninguém quer e por quê"],
      structures: ["Hook curto → problema → 3 dicas → CTA direto"],
      ctas: ["Me chama no direct pra avaliar seu caso"],
      themes: ["avaliação de imóveis", "precificação", "erros comuns"],
      observations: "Perfil foca em conteúdo educacional para corretores iniciantes, tom direto e objetivo."
    )
  end

  let(:carousel_insights_json) do
    JSON.generate(
      structures: ["Slide gancho → desenvolvimento → CTA final"],
      content_types: ["educacional", "checklist"],
      themes: ["documentação", "financiamento"],
      observations: "Carrosséis com checklist têm alta taxa de salvamentos. Slides objetivos."
    )
  end

  let(:image_insights_json) do
    JSON.generate(
      caption_styles: ["informativo", "comercial direto"],
      visual_elements: ["preço visível na imagem", "localização destacada"],
      themes: ["apartamentos prontos", "lançamentos"],
      observations: "Imagens com preço têm maior engajamento. Composição simples e clara funciona."
    )
  end

  before do
    # Mock scraper
    mock_scraper = instance_double(Scraping::ApifyProvider)
    allow(Scraping::Factory).to receive(:build).and_return(mock_scraper)
    allow(mock_scraper).to receive(:scrape_profile).and_return(scraping_result)

    # Mock transcription — defaults to assemblyai (transcription_provider default)
    mock_transcriber = instance_double(Transcription::Providers::AssemblyAI)
    allow(Transcription::Factory).to receive(:build)
      .with(provider: :assemblyai, api_key: instance_of(String))
      .and_return(mock_transcriber)
    allow(mock_transcriber).to receive(:transcribe)
      .and_return(Transcription::Result.success(
        transcript: "Bom dia pessoal, hoje vou falar sobre três erros comuns na hora de avaliar um imóvel...",
        duration_seconds: 42
      ))

    # Stub LLM::Gateway.build_provider so the real constructor (which requires API keys) is bypassed.
    # AnalyzeStep (3 calls) uses :openai (analysis_provider default)
    # GenerateSuggestionsStep removido do pipeline automático — sugestões on-demand via controller.
    reel_resp     = build_llm_response(reel_insights_json, model: "gpt-4o-mini", provider: :openai)
    carousel_resp = build_llm_response(carousel_insights_json, model: "gpt-4o-mini", provider: :openai)
    image_resp    = build_llm_response(image_insights_json, model: "gpt-4o-mini", provider: :openai)

    openai_stub = instance_double(LLM::Providers::OpenAI)
    allow(openai_stub).to receive(:complete)
      .and_return(reel_resp, carousel_resp, image_resp)
    allow(LLM::Gateway).to receive(:build_provider).with(:openai, api_key: instance_of(String)).and_return(openai_stub)
  end

  # Helper: run pipeline and assertions inside tenant context
  def run_pipeline(analysis, account, &block)
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      block.call if block
    end
  end

  it "runs the full pipeline end-to-end and reaches completed status" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)

      reloaded = analysis.reload
      expect(reloaded.status).to eq("completed")
      expect(reloaded.started_at).to be_present
      expect(reloaded.finished_at).to be_present
    end
  end

  it "scrapes and persists 30 posts" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      expect(analysis.reload.posts_scraped_count).to eq(30)
      expect(analysis.posts.count).to eq(30)
    end
  end

  it "computes profile_metrics" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      expect(analysis.reload.profile_metrics).to include("posts_per_week", "content_mix")
    end
  end

  it "selects top posts and stores posts_analyzed_count" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      # ScoreAndSelectStep selects up to 12 reels + 5 carousels + 3 images = 20
      expect(analysis.reload.posts_analyzed_count).to eq(20)
      expect(analysis.posts.where(selected_for_analysis: true).count).to eq(20)
    end
  end

  it "transcribes the 12 selected reels via assemblyai (default transcription provider)" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      expect(analysis.posts.where(transcript_status: "completed").count).to eq(12)
      expect(Transcription::Factory).to have_received(:build)
        .with(provider: :assemblyai, api_key: instance_of(String))
        .at_least(12).times
    end
  end

  it "populates insights with all 3 keys" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      expect(analysis.reload.insights.keys).to match_array(%w[reels carousels images])
    end
  end

  it "does not create ContentSuggestions (geradas on-demand, não mais pelo pipeline)" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      expect(analysis.reload.content_suggestions.count).to eq(0)
    end
  end

  it "creates LLMUsageLog for each LLM call" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      # 3 analyze calls (openai) — GenerateSuggestionsStep removido do pipeline
      expect(LLMUsageLog.where(analysis: analysis).count).to eq(3)
    end
  end

  it "creates TranscriptionUsageLog for each successful transcription" do
    ActsAsTenant.with_tenant(account) do
      Analyses::RunAnalysisWorker.new.perform(analysis.id)
      expect(TranscriptionUsageLog.where(analysis: analysis).count).to eq(12)
    end
  end
end
