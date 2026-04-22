require "rails_helper"

RSpec.describe Analyses::TopPostsExporter do
  let(:account) { create(:account) }
  let(:competitor) { ActsAsTenant.with_tenant(account) { create(:competitor, account: account, instagram_handle: "meu_handle") } }
  let(:analysis) { ActsAsTenant.with_tenant(account) { create(:analysis, :completed, account: account, competitor: competitor) } }

  subject(:exporter) { described_class.new(analysis) }

  def build_post(type:, score:, **attrs)
    ActsAsTenant.with_tenant(account) do
      create(:post, type, account: account, competitor: competitor, analysis: analysis,
             quality_score: score, **attrs)
    end
  end

  describe "#call" do
    it "retorna uma String" do
      expect(exporter.call).to be_a(String)
    end

    it "inclui o handle do competitor no header" do
      result = exporter.call
      expect(result).to include("@meu_handle")
    end

    it "inclui o id da análise no header" do
      result = exporter.call
      expect(result).to include(analysis.id.to_s)
    end

    context "seção REELS" do
      before do
        build_post(type: :reel, score: 10.0)
        build_post(type: :reel, score: 90.0)
        build_post(type: :reel, score: 50.0)
      end

      it "inclui seção REELS" do
        expect(exporter.call).to include("REELS")
      end

      it "ordena por quality_score decrescente" do
        result = exporter.call
        pos_90 = result.index("90.0")
        pos_50 = result.index("50.0")
        pos_10 = result.index("10.0")
        expect(pos_90).to be < pos_50
        expect(pos_50).to be < pos_10
      end

      it "inclui até 8 reels mesmo que existam mais" do
        5.times { build_post(type: :reel, score: rand(1.0..9.0)) }
        result = exporter.call
        matches = result.scan(/\[\d+\] quality_score:/).select do |m|
          result.index(m) < result.index("CARROSSÉIS")
        end
        expect(matches.size).to be <= 8
      end

      it "inclui campo Transcrição nos reels" do
        expect(exporter.call).to include("Transcrição:")
      end

      it "exibe '(sem transcrição)' quando transcript é nil" do
        build_post(type: :reel, score: 5.0, transcript: nil)
        expect(exporter.call).to include("(sem transcrição)")
      end
    end

    context "quando não há reels" do
      it "inclui mensagem de nenhum post encontrado na seção REELS" do
        result = exporter.call
        expect(result).to include("(nenhum post encontrado para este tipo)")
      end
    end

    context "seção CARROSSÉIS" do
      before do
        build_post(type: :carousel, score: 20.0)
        build_post(type: :carousel, score: 80.0)
      end

      it "inclui seção CARROSSÉIS" do
        expect(exporter.call).to include("CARROSSÉIS")
      end

      it "ordena carrosséis por quality_score decrescente" do
        result = exporter.call
        pos_80 = result.rindex("80.0")
        pos_20 = result.rindex("20.0")
        expect(pos_80).to be < pos_20
      end

      it "inclui até 5 carrosséis mesmo que existam mais" do
        4.times { build_post(type: :carousel, score: rand(1.0..9.0)) }
        result = exporter.call
        carousel_section_start = result.index("CARROSSÉIS")
        carousel_matches = result[carousel_section_start..].scan(/\[\d+\] quality_score:/)
        expect(carousel_matches.size).to be <= 5
      end

      it "NÃO inclui campo Transcrição nos carrosséis" do
        build_post(type: :carousel, score: 5.0, transcript: nil)
        carousel_section_start = exporter.call.index("CARROSSÉIS")
        carousel_text = exporter.call[carousel_section_start..]
        expect(carousel_text).not_to include("Transcrição:")
      end
    end

    context "quando não há carrosséis" do
      before { build_post(type: :reel, score: 1.0) }

      it "inclui mensagem de nenhum post encontrado na seção CARROSSÉIS" do
        result = exporter.call
        carousel_section_start = result.index("CARROSSÉIS")
        expect(result[carousel_section_start..]).to include("(nenhum post encontrado para este tipo)")
      end
    end

    context "posts do tipo image" do
      before do
        build_post(type: :image, score: 999.0, caption: "foto de imóvel")
      end

      it "não aparecem no export" do
        expect(exporter.call).not_to include("foto de imóvel")
      end
    end

    context "posts sem caption" do
      before { build_post(type: :reel, score: 5.0, caption: nil) }

      it "exibe '(sem caption)'" do
        expect(exporter.call).to include("(sem caption)")
      end
    end
  end
end
