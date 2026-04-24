require "rails_helper"

RSpec.describe Playbooks::GenerateSuggestionsService do
  let(:account) { create(:account) }
  let(:playbook_with_version) do
    ActsAsTenant.with_tenant(account) { create(:playbook, :with_version, account: account) }
  end
  let(:playbook_without_version) do
    ActsAsTenant.with_tenant(account) { create(:playbook, account: account) }
  end

  let(:llm_response) do
    instance_double(LLM::Response,
      content: JSON.generate({
        "suggestions" => [ {
          "hook" => "Gancho teste",
          "caption_draft" => "Caption teste",
          "format_details" => {},
          "suggested_hashtags" => [ "imoveis" ],
          "rationale" => "Funciona porque..."
        } ]
      })
    )
  end
  let(:requested_content_type) { "reel" }
  let(:quantity) { 1 }
  let(:render_calls) { [] }
  let(:llm_calls) { [] }

  def call_service(playbook: playbook_with_version, content_type: requested_content_type, quantity: 1)
    ActsAsTenant.with_tenant(account) do
      described_class.call(
        playbook: playbook,
        content_type: content_type,
        quantity: quantity
      )
    end
  end

  def prompt_render_call
    render_calls.find { |call| call[:step] == "playbook_suggestions" && call[:kind] == :user }
  end

  def rendered_prompt
    llm_calls.last.dig(:messages, 0, :content)
  end

  describe ".call" do
    context "playbook sem versão" do
      it "retorna failure com error_code :no_content" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(
            playbook: playbook_without_version,
            content_type: "reel",
            quantity: 1
          )
          expect(result).to be_failure
          expect(result.error_code).to eq(:no_content)
        end
      end
    end

    context "sem credential configurada" do
      it "retorna failure com error_code :no_credential" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(
            playbook: playbook_with_version,
            content_type: "reel",
            quantity: 1
          )
          expect(result).to be_failure
          expect(result.error_code).to eq(:no_credential)
        end
      end
    end

    context "com credential e LLM retornando JSON válido" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test")
        end
        allow(Analyses::PromptRenderer).to receive(:render).and_wrap_original do |method, *args, **kwargs|
          call = kwargs.presence || args.first
          render_calls << call
          method.call(*args, **kwargs)
        end

        allow(LLM::Gateway).to receive(:complete).and_wrap_original do |_method, *args, **kwargs|
          call = kwargs.presence || args.first
          llm_calls << call
          llm_response
        end
      end

      it "retorna success com sugestões" do
        result = call_service

        expect(result).to be_success
        expect(result.data[:suggestions]).not_to be_empty
      end

      it "persiste PlaybookSuggestion no banco" do
        expect { call_service }.to change(PlaybookSuggestion, :count).by(1)
      end

      it "chama LLM com use_case playbook_suggestions" do
        call_service

        expect(LLM::Gateway).to have_received(:complete).with(
          hash_including(use_case: "playbook_suggestions", json_mode: true)
        )
      end

      it "passa previous_suggestions vazio e nao renderiza o bloco quando nao ha historico" do
        call_service(content_type: "carousel")

        expect(prompt_render_call.dig(:locals, :previous_suggestions)).to eq([])
        expect(rendered_prompt).not_to include("## Sugestões já geradas anteriormente para este playbook e content_type")
      end

      it "inclui historico do mesmo content_type no renderer e no prompt" do
        older_suggestion = ActsAsTenant.with_tenant(account) do
          create(
            :playbook_suggestion,
            playbook: playbook_with_version,
            account: account,
            content_type: "reel",
            hook: "Gancho antigo",
            rationale: "Prova social com objecao comum.",
            created_at: 2.days.ago
          )
        end

        newer_suggestion = ActsAsTenant.with_tenant(account) do
          create(
            :playbook_suggestion,
            playbook: playbook_with_version,
            account: account,
            content_type: "reel",
            status: :saved,
            hook: "Gancho recente",
            rationale: "Abre com contraste forte do nicho.",
            created_at: 1.day.ago
          )
        end

        call_service

        expect(prompt_render_call.dig(:locals, :previous_suggestions)).to eq([
          { hook: newer_suggestion.hook, rationale: newer_suggestion.rationale },
          { hook: older_suggestion.hook, rationale: older_suggestion.rationale }
        ])
        expect(rendered_prompt).to include("## Sugestões já geradas anteriormente para este playbook e content_type")
        expect(rendered_prompt).to include(newer_suggestion.hook)
        expect(rendered_prompt).to include(older_suggestion.hook)
      end

      it "ignora sugestoes discarded no historico" do
        visible_suggestion = ActsAsTenant.with_tenant(account) do
          create(
            :playbook_suggestion,
            playbook: playbook_with_version,
            account: account,
            content_type: "reel",
            hook: "Gancho valido",
            rationale: "Baseado em dor recorrente."
          )
        end

        ActsAsTenant.with_tenant(account) do
          create(
            :playbook_suggestion,
            playbook: playbook_with_version,
            account: account,
            content_type: "reel",
            status: :discarded,
            hook: "Gancho descartado",
            rationale: "Nao deve aparecer."
          )
        end

        call_service

        expect(prompt_render_call.dig(:locals, :previous_suggestions)).to eq([
          { hook: visible_suggestion.hook, rationale: visible_suggestion.rationale }
        ])
        expect(rendered_prompt).to include(visible_suggestion.hook)
        expect(rendered_prompt).not_to include("Gancho descartado")
      end

      it "ignora sugestoes de outro content_type" do
        matching_suggestion = ActsAsTenant.with_tenant(account) do
          create(
            :playbook_suggestion,
            playbook: playbook_with_version,
            account: account,
            content_type: "carousel",
            hook: "Hook do carrossel",
            rationale: "Lista direta."
          )
        end

        ActsAsTenant.with_tenant(account) do
          create(
            :playbook_suggestion,
            playbook: playbook_with_version,
            account: account,
            content_type: "reel",
            hook: "Hook do reel",
            rationale: "Nao deve entrar."
          )
        end

        call_service(content_type: "carousel")

        expect(prompt_render_call.dig(:locals, :previous_suggestions)).to eq([
          { hook: matching_suggestion.hook, rationale: matching_suggestion.rationale }
        ])
        expect(rendered_prompt).to include(matching_suggestion.hook)
        expect(rendered_prompt).not_to include("Hook do reel")
      end

      it "limita o historico as 20 sugestoes mais recentes" do
        retained_hooks = []

        ActsAsTenant.with_tenant(account) do
          21.times do |index|
            suggestion = create(
              :playbook_suggestion,
              playbook: playbook_with_version,
              account: account,
              content_type: "reel",
              hook: "Gancho #{index}",
              rationale: "Rationale #{index}",
              created_at: index.minutes.ago
            )
            retained_hooks << suggestion.hook if index < 20
          end
        end

        call_service

        previous_suggestions = prompt_render_call.dig(:locals, :previous_suggestions)

        expect(previous_suggestions.size).to eq(20)
        expect(previous_suggestions.map { |item| item[:hook] }).to eq(retained_hooks)
        expect(previous_suggestions.map { |item| item[:hook] }).not_to include("Gancho 20")
      end

      it "usa fallback do caption_draft quando hook esta vazio" do
        fallback_caption = "A" * 100

        ActsAsTenant.with_tenant(account) do
          create(
            :playbook_suggestion,
            playbook: playbook_with_version,
            account: account,
            content_type: "reel",
            hook: nil,
            caption_draft: fallback_caption,
            rationale: "Fallback pelo caption."
          )
        end

        call_service

        expect(prompt_render_call.dig(:locals, :previous_suggestions)).to eq([
          { hook: fallback_caption.first(80), rationale: "Fallback pelo caption." }
        ])
      end

      it "pula sugestao sem hook e sem caption_draft utilizavel" do
        ActsAsTenant.with_tenant(account) do
          create(
            :playbook_suggestion,
            playbook: playbook_with_version,
            account: account,
            content_type: "reel",
            hook: nil,
            caption_draft: "   ",
            rationale: "Nao deve entrar."
          )
        end

        call_service

        expect(prompt_render_call.dig(:locals, :previous_suggestions)).to eq([])
      end
    end

    context "LLM retorna JSON inválido" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, :anthropic, account: account, encrypted_api_key: "sk-ant-test")
        end
        invalid_response = instance_double(LLM::Response, content: "não é JSON")
        allow(LLM::Gateway).to receive(:complete).and_return(invalid_response)
      end

      it "retorna failure com error_code :parse_error" do
        ActsAsTenant.with_tenant(account) do
          result = described_class.call(
            playbook: playbook_with_version,
            content_type: "reel",
            quantity: 1
          )
          expect(result).to be_failure
          expect(result.error_code).to eq(:parse_error)
        end
      end
    end
  end
end
