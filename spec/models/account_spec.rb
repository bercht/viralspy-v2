require 'rails_helper'

RSpec.describe Account, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:users).dependent(:destroy) }
  end

  describe "#llm_preferences_with_defaults" do
    let(:account) { create(:account) }

    it "returns defaults when llm_preferences is empty" do
      expect(account.llm_preferences_with_defaults).to eq(
        "transcription_provider" => "assemblyai",
        "transcription_model" => "default",
        "analysis_provider" => "openai",
        "analysis_model" => "gpt-4o-mini",
        "generation_provider" => "anthropic",
        "generation_model" => "claude-sonnet-4-6"
      )
    end

    it "merges account preferences over defaults" do
      account.update!(llm_preferences: { "analysis_provider" => "anthropic", "analysis_model" => "claude-opus-4-7" })
      prefs = account.llm_preferences_with_defaults
      expect(prefs["analysis_provider"]).to eq("anthropic")
      expect(prefs["analysis_model"]).to eq("claude-opus-4-7")
      expect(prefs["generation_provider"]).to eq("anthropic")
      expect(prefs["transcription_provider"]).to eq("assemblyai")
    end

    it "handles empty llm_preferences gracefully" do
      account.llm_preferences = {}
      expect { account.llm_preferences_with_defaults }.not_to raise_error
      expect(account.llm_preferences_with_defaults["analysis_provider"]).to eq("openai")
    end
  end

  describe "#api_credential_for" do
    let(:account) { create(:account) }

    it "returns active credential for provider" do
      ActsAsTenant.with_tenant(account) do
        cred = create(:api_credential, account: account, provider: "openai", active: true)
        expect(account.api_credential_for("openai")).to eq(cred)
        expect(account.api_credential_for(:openai)).to eq(cred)
      end
    end

    it "returns nil when credential exists but is inactive" do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, :inactive, account: account, provider: "openai")
        expect(account.api_credential_for("openai")).to be_nil
      end
    end

    it "returns nil when no credential exists for provider" do
      ActsAsTenant.with_tenant(account) do
        expect(account.api_credential_for("assemblyai")).to be_nil
      end
    end
  end

  describe "factory trait :with_credentials" do
    it "creates credentials for all 3 providers" do
      account = create(:account, :with_credentials)
      ActsAsTenant.with_tenant(account) do
        expect(account.api_credentials.count).to eq(3)
        providers = account.api_credentials.pluck(:provider).sort
        expect(providers).to eq(%w[anthropic assemblyai openai])
      end
    end
  end

  describe "#ready_for_analysis?" do
    let(:account) { create(:account) }

    context "when all 3 credentials are active" do
      it "returns true" do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "openai")
          create(:api_credential, account: account, provider: "anthropic")
          create(:api_credential, account: account, provider: "assemblyai")

          expect(account.ready_for_analysis?).to be true
        end
      end
    end

    context "when assemblyai credential is missing" do
      it "returns false" do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "openai")
          create(:api_credential, account: account, provider: "anthropic")

          expect(account.ready_for_analysis?).to be false
        end
      end
    end

    context "when credential exists but is inactive" do
      it "returns false" do
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "openai")
          create(:api_credential, account: account, provider: "anthropic")
          create(:api_credential, :inactive, account: account, provider: "assemblyai")

          expect(account.ready_for_analysis?).to be false
        end
      end
    end

    context "when llm_preferences overrides analysis_provider to anthropic" do
      it "checks anthropic credential (not openai) for analysis use case" do
        ActsAsTenant.with_tenant(account) do
          account.update!(llm_preferences: { "analysis_provider" => "anthropic" })
          create(:api_credential, account: account, provider: "anthropic")
          create(:api_credential, account: account, provider: "assemblyai")

          expect(account.ready_for_analysis?).to be true
        end
      end
    end

    context "when same provider serves multiple use cases" do
      it "deduplicates and requires credential only once" do
        ActsAsTenant.with_tenant(account) do
          account.update!(llm_preferences: {
            "analysis_provider" => "anthropic",
            "generation_provider" => "anthropic"
          })
          create(:api_credential, account: account, provider: "anthropic")
          create(:api_credential, account: account, provider: "assemblyai")

          expect(account.ready_for_analysis?).to be true
        end
      end
    end
  end

  describe "#missing_credentials_for_analysis" do
    let(:account) { create(:account) }

    it "returns empty array when all credentials are present" do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, account: account, provider: "openai")
        create(:api_credential, account: account, provider: "anthropic")
        create(:api_credential, account: account, provider: "assemblyai")

        expect(account.missing_credentials_for_analysis).to eq([])
      end
    end

    it "returns only missing providers" do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, account: account, provider: "openai")
        create(:api_credential, account: account, provider: "anthropic")

        expect(account.missing_credentials_for_analysis).to eq([:assemblyai])
      end
    end

    it "returns all 3 providers when no credentials exist" do
      ActsAsTenant.with_tenant(account) do
        expect(account.missing_credentials_for_analysis).to contain_exactly(:assemblyai, :openai, :anthropic)
      end
    end

    it "does not duplicate when same provider is required by multiple use cases" do
      ActsAsTenant.with_tenant(account) do
        account.update!(llm_preferences: {
          "analysis_provider" => "anthropic",
          "generation_provider" => "anthropic"
        })

        expect(account.missing_credentials_for_analysis).to contain_exactly(:assemblyai, :anthropic)
        expect(account.missing_credentials_for_analysis.length).to eq(2)
      end
    end
  end
end
