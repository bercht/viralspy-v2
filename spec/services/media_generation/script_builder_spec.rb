require "rails_helper"

RSpec.describe MediaGeneration::ScriptBuilder do
  def build_suggestion(hook: nil, caption_draft: "")
    instance_double(ContentSuggestion, hook: hook, caption_draft: caption_draft)
  end

  describe ".build" do
    context "com hook e caption completos" do
      let(:suggestion) do
        build_suggestion(
          hook: "3 erros que corretores cometem",
          caption_draft: "Primeiro erro é não fazer follow-up. Segundo erro é não qualificar."
        )
      end

      it "inclui gancho formatado no início" do
        script = described_class.build(suggestion: suggestion)
        expect(script).to start_with("3 erros que corretores cometem!")
      end

      it "inclui corpo do caption" do
        script = described_class.build(suggestion: suggestion)
        expect(script).to include("Primeiro erro")
      end
    end

    context "com hook sem pontuação" do
      let(:suggestion) { build_suggestion(hook: "Erro comum", caption_draft: "Corpo do texto") }

      it "adiciona ! ao final do hook" do
        script = described_class.build(suggestion: suggestion)
        expect(script).to start_with("Erro comum!")
      end
    end

    context "com hook já terminando em ?" do
      let(:suggestion) { build_suggestion(hook: "Você comete esse erro?", caption_draft: "Corpo") }

      it "não adiciona ! ao hook" do
        script = described_class.build(suggestion: suggestion)
        expect(script).to start_with("Você comete esse erro?")
        expect(script).not_to start_with("Você comete esse erro?!")
      end
    end

    context "com caption com hashtags e menções" do
      let(:suggestion) do
        build_suggestion(
          hook: "Dica",
          caption_draft: "Texto importante #imoveis #corretor @amigo texto final"
        )
      end

      it "remove hashtags" do
        script = described_class.build(suggestion: suggestion)
        expect(script).not_to include("#imoveis")
        expect(script).not_to include("#corretor")
      end

      it "remove menções" do
        script = described_class.build(suggestion: suggestion)
        expect(script).not_to include("@amigo")
      end
    end

    context "com caption que já tem CTA" do
      let(:suggestion) do
        build_suggestion(
          hook: "Dica",
          caption_draft: "Texto do corpo. Me segue para mais conteúdo."
        )
      end

      it "não adiciona CTA duplicado" do
        script = described_class.build(suggestion: suggestion)
        expect(script.scan("Me segue").length).to eq(1)
      end
    end

    context "com caption sem CTA" do
      let(:suggestion) do
        build_suggestion(hook: "Dica", caption_draft: "Apenas informação aqui.")
      end

      it "adiciona CTA padrão" do
        script = described_class.build(suggestion: suggestion)
        expect(script).to include("Me segue para mais dicas como essa!")
      end
    end

    context "com texto muito longo" do
      let(:suggestion) do
        build_suggestion(hook: "Hook", caption_draft: "a" * 2000)
      end

      it "trunca em MAX_SCRIPT_CHARS" do
        script = described_class.build(suggestion: suggestion)
        expect(script.length).to be <= MediaGeneration::ScriptBuilder::MAX_SCRIPT_CHARS
      end
    end

    context "sem hook" do
      let(:suggestion) { build_suggestion(hook: nil, caption_draft: "Corpo do texto aqui.") }

      it "gera script apenas com body e CTA" do
        script = described_class.build(suggestion: suggestion)
        expect(script).to include("Corpo do texto aqui.")
      end
    end
  end
end
