require "rails_helper"

RSpec.describe Playbooks::TopPostsExporter do
  let(:account) { create(:account) }
  let(:playbook) do
    ActsAsTenant.with_tenant(account) { create(:playbook, account: account, name: "Meu Playbook", niche: "imóveis") }
  end

  subject(:exporter) { described_class.new(playbook) }

  def make_competitor(handle:, followers: nil)
    ActsAsTenant.with_tenant(account) do
      create(:competitor, account: account, instagram_handle: handle, followers_count: followers)
    end
  end

  def make_analysis(competitor:)
    ActsAsTenant.with_tenant(account) do
      create(:analysis, :completed, account: account, competitor: competitor)
    end
  end

  def link_analysis(analysis)
    create(:analysis_playbook, analysis: analysis, playbook: playbook)
  end

  def make_post(analysis:, competitor:, type:, score:, **attrs)
    ActsAsTenant.with_tenant(account) do
      create(:post, type, account: account, competitor: competitor, analysis: analysis,
             quality_score: score, **attrs)
    end
  end

  describe "#call" do
    it "retorna uma String" do
      expect(exporter.call).to be_a(String)
    end

    context "sem análises completas vinculadas" do
      it "retorna texto de fallback sem levantar erro" do
        result = exporter.call
        expect(result).to include("Meu Playbook")
        expect(result).to include("Nenhuma análise completa")
      end
    end

    context "com uma análise completa vinculada" do
      let(:competitor) { make_competitor(handle: "meu_handle", followers: 1500) }
      let(:analysis)   { make_analysis(competitor: competitor) }

      before do
        link_analysis(analysis)
        make_post(analysis: analysis, competitor: competitor, type: :reel, score: 10.0)
        make_post(analysis: analysis, competitor: competitor, type: :carousel, score: 5.0)
      end

      it "inclui nome do playbook no header" do
        expect(exporter.call).to include("Meu Playbook")
      end

      it "inclui contagem de análises no header" do
        expect(exporter.call).to include("1 análises")
      end

      it "inclui contagem de competitors no header" do
        expect(exporter.call).to include("1 competitors")
      end

      it "inclui contagem de reels no header" do
        expect(exporter.call).to include("1 reels")
      end

      it "inclui contagem de carrosséis no header" do
        expect(exporter.call).to include("1 carrosséis")
      end

      it "inclui handle do competitor" do
        expect(exporter.call).to include("@meu_handle")
      end

      it "inclui followers_count do competitor" do
        expect(exporter.call).to include("1500 seguidores")
      end

      it "inclui campo Transcrição nos reels" do
        expect(exporter.call).to include("Transcrição:")
      end

      it "NÃO inclui campo Transcrição nos carrosséis" do
        result = exporter.call
        carousel_section_start = result.index("CARROSSÉIS")
        expect(result[carousel_section_start..]).not_to include("Transcrição:")
      end
    end

    context "competitor sem followers_count" do
      let(:competitor) { make_competitor(handle: "sem_followers", followers: nil) }
      let(:analysis)   { make_analysis(competitor: competitor) }

      before do
        link_analysis(analysis)
        make_post(analysis: analysis, competitor: competitor, type: :reel, score: 3.0)
      end

      it "exibe 'seguidores desconhecidos'" do
        expect(exporter.call).to include("seguidores desconhecidos")
      end
    end

    context "posts de tipo image" do
      let(:competitor) { make_competitor(handle: "comp_img") }
      let(:analysis)   { make_analysis(competitor: competitor) }

      before do
        link_analysis(analysis)
        make_post(analysis: analysis, competitor: competitor, type: :image, score: 999.0, caption: "foto exclusiva")
      end

      it "não aparecem no export" do
        expect(exporter.call).not_to include("foto exclusiva")
      end
    end

    context "posts com quality_score nil ou zero" do
      let(:competitor) { make_competitor(handle: "comp_zero") }
      let(:analysis)   { make_analysis(competitor: competitor) }

      before do
        link_analysis(analysis)
        make_post(analysis: analysis, competitor: competitor, type: :reel, score: 0, caption: "zero score")
        make_post(analysis: analysis, competitor: competitor, type: :reel, score: nil, caption: "nil score")
      end

      it "não aparecem no export" do
        result = exporter.call
        expect(result).not_to include("zero score")
        expect(result).not_to include("nil score")
      end
    end

    context "deduplicação por instagram_post_id" do
      let(:competitor) { make_competitor(handle: "dup_comp") }
      let(:analysis1)  { make_analysis(competitor: competitor) }
      let(:analysis2)  { make_analysis(competitor: competitor) }

      before do
        link_analysis(analysis1)
        link_analysis(analysis2)

        # mesmo instagram_post_id em duas análises diferentes
        ActsAsTenant.with_tenant(account) do
          create(:post, :reel, account: account, competitor: competitor, analysis: analysis1,
                 instagram_post_id: "ig_dup_001", quality_score: 30.0, caption: "versão baixa score")
          create(:post, :reel, account: account, competitor: competitor, analysis: analysis2,
                 instagram_post_id: "ig_dup_001", quality_score: 80.0, caption: "versão alta score")
        end
      end

      it "o post duplicado aparece apenas uma vez" do
        result = exporter.call
        expect(result.scan("[1] quality_score:").size).to eq(1)
      end

      it "mantém a ocorrência com maior quality_score" do
        expect(exporter.call).to include("versão alta score")
        expect(exporter.call).not_to include("versão baixa score")
      end
    end

    context "ordenação por quality_score" do
      let(:competitor) { make_competitor(handle: "ordem_comp") }
      let(:analysis)   { make_analysis(competitor: competitor) }

      before do
        link_analysis(analysis)
        make_post(analysis: analysis, competitor: competitor, type: :reel, score: 10.0)
        make_post(analysis: analysis, competitor: competitor, type: :reel, score: 90.0)
        make_post(analysis: analysis, competitor: competitor, type: :reel, score: 50.0)
        make_post(analysis: analysis, competitor: competitor, type: :carousel, score: 20.0)
        make_post(analysis: analysis, competitor: competitor, type: :carousel, score: 70.0)
      end

      it "reels aparecem em ordem decrescente de quality_score" do
        result = exporter.call
        pos_90 = result.index("90.0")
        pos_50 = result.index("50.0")
        pos_10 = result.index("10.0")
        expect(pos_90).to be < pos_50
        expect(pos_50).to be < pos_10
      end

      it "carrosséis aparecem em ordem decrescente de quality_score" do
        result = exporter.call
        carousel_start = result.index("CARROSSÉIS")
        pos_70 = result.index("70.0", carousel_start)
        pos_20 = result.index("20.0", carousel_start)
        expect(pos_70).to be < pos_20
      end
    end

    context "agrupamento por competitor" do
      let(:competitor_a) { make_competitor(handle: "comp_a") }
      let(:competitor_b) { make_competitor(handle: "comp_b") }
      let(:analysis_a)   { make_analysis(competitor: competitor_a) }
      let(:analysis_b)   { make_analysis(competitor: competitor_b) }

      before do
        link_analysis(analysis_a)
        link_analysis(analysis_b)
        make_post(analysis: analysis_a, competitor: competitor_a, type: :reel, score: 5.0)
        make_post(analysis: analysis_b, competitor: competitor_b, type: :reel, score: 5.0)
      end

      it "inclui seção para cada competitor" do
        result = exporter.call
        expect(result).to include("@comp_a")
        expect(result).to include("@comp_b")
      end
    end

    context "análise pendente vinculada" do
      let(:competitor) { make_competitor(handle: "pending_comp") }

      before do
        pending_analysis = ActsAsTenant.with_tenant(account) do
          create(:analysis, account: account, competitor: competitor, status: :pending)
        end
        create(:analysis_playbook, analysis: pending_analysis, playbook: playbook)
      end

      it "ignora análises não-completas" do
        result = exporter.call
        expect(result).to include("Nenhuma análise completa")
      end
    end

    context "posts sem caption ou transcrição" do
      let(:competitor) { make_competitor(handle: "null_fields") }
      let(:analysis)   { make_analysis(competitor: competitor) }

      before do
        link_analysis(analysis)
        make_post(analysis: analysis, competitor: competitor, type: :reel, score: 5.0,
                  caption: nil, transcript: nil)
      end

      it "exibe '(sem caption)'" do
        expect(exporter.call).to include("(sem caption)")
      end

      it "exibe '(sem transcrição)'" do
        expect(exporter.call).to include("(sem transcrição)")
      end
    end
  end
end
