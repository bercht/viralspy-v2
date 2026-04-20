require 'rails_helper'

RSpec.describe ApiCredential, type: :model do
  let(:account) { create(:account) }

  describe "associations" do
    it "belongs to account" do
      ActsAsTenant.with_tenant(account) do
        credential = build(:api_credential, account: account)
        expect(credential.account).to eq(account)
      end
    end
  end

  describe "validations" do
    it "requires provider" do
      ActsAsTenant.with_tenant(account) do
        credential = build(:api_credential, account: account, provider: nil)
        expect(credential).not_to be_valid
        expect(credential.errors[:provider]).to be_present
      end
    end

    it "rejects unknown provider" do
      ActsAsTenant.with_tenant(account) do
        expect {
          build(:api_credential, account: account, provider: "unknown")
        }.to raise_error(ArgumentError, /is not a valid provider/)
      end
    end

    it "accepts openai, anthropic, assemblyai" do
      ActsAsTenant.with_tenant(account) do
        %w[openai anthropic assemblyai].each do |p|
          credential = build(:api_credential, account: account, provider: p)
          expect(credential).to be_valid, "provider #{p} should be valid"
        end
      end
    end

    it "requires encrypted_api_key" do
      ActsAsTenant.with_tenant(account) do
        credential = build(:api_credential, account: account, encrypted_api_key: nil)
        expect(credential).not_to be_valid
        expect(credential.errors[:encrypted_api_key]).to be_present
      end
    end

    it "enforces uniqueness of (account, provider)" do
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, account: account, provider: "openai")
        dup = build(:api_credential, account: account, provider: "openai")
        expect(dup).not_to be_valid
        expect(dup.errors[:account_id]).to be_present
      end
    end

    it "allows same provider across different accounts" do
      other_account = create(:account)
      ActsAsTenant.with_tenant(account) do
        create(:api_credential, account: account, provider: "openai")
      end
      ActsAsTenant.with_tenant(other_account) do
        credential = build(:api_credential, account: other_account, provider: "openai")
        expect(credential).to be_valid
      end
    end
  end

  describe "enums" do
    describe "provider" do
      it "stores value as string in the database" do
        ActsAsTenant.with_tenant(account) do
          credential = create(:api_credential, account: account, provider: "anthropic")
          raw = ApiCredential.connection.select_value(
            "SELECT provider FROM api_credentials WHERE id = #{credential.id}"
          )
          expect(raw).to eq("anthropic")
        end
      end

      it "exposes predicate methods with provider_ prefix" do
        ActsAsTenant.with_tenant(account) do
          credential = build(:api_credential, account: account, provider: "openai")
          expect(credential.provider_openai?).to be true
          expect(credential.provider_anthropic?).to be false
        end
      end
    end

    describe "last_validation_status" do
      it "defaults to unknown" do
        ActsAsTenant.with_tenant(account) do
          credential = create(:api_credential, account: account)
          expect(credential.last_validation_status).to eq("unknown")
        end
      end

      it "accepts status transitions" do
        ActsAsTenant.with_tenant(account) do
          credential = create(:api_credential, account: account)
          credential.last_validation_status = :verified
          expect(credential).to be_valid
          credential.save!
          expect(credential.reload.last_validation_status).to eq("verified")
        end
      end
    end
  end

  describe "encryption" do
    it "encrypts encrypted_api_key at rest" do
      ActsAsTenant.with_tenant(account) do
        plaintext = "sk-super-secret-12345"
        credential = create(:api_credential, account: account, encrypted_api_key: plaintext)

        raw_value = ApiCredential.connection.select_value(
          "SELECT encrypted_api_key FROM api_credentials WHERE id = #{credential.id}"
        )

        expect(raw_value).not_to eq(plaintext)
        expect(raw_value).not_to include(plaintext)
        expect(credential.reload.encrypted_api_key).to eq(plaintext)
      end
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active credentials" do
        ActsAsTenant.with_tenant(account) do
          active = create(:api_credential, account: account, provider: "openai", active: true)
          create(:api_credential, :inactive, account: account, provider: "anthropic")
          expect(ApiCredential.active).to contain_exactly(active)
        end
      end
    end
  end

  describe "#api_key / #api_key=" do
    it "is an alias for encrypted_api_key" do
      ActsAsTenant.with_tenant(account) do
        credential = build(:api_credential, account: account)
        credential.api_key = "sk-new-key"
        expect(credential.encrypted_api_key).to eq("sk-new-key")
        expect(credential.api_key).to eq("sk-new-key")
      end
    end
  end
end
