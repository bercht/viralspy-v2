require "rails_helper"

RSpec.describe Playbook, type: :model do
  let(:account) { create(:account) }

  describe "validations" do
    it "requires name" do
      ActsAsTenant.with_tenant(account) do
        playbook = build(:playbook, account: account, name: nil)
        expect(playbook).not_to be_valid
        expect(playbook.errors[:name]).to be_present
      end
    end

    it "requires unique name per account (case-insensitive)" do
      ActsAsTenant.with_tenant(account) do
        create(:playbook, account: account, name: "Marketing")
        duplicate = build(:playbook, account: account, name: "marketing")
        expect(duplicate).not_to be_valid
      end
    end

    it "allows same name across different accounts" do
      other_account = create(:account)
      ActsAsTenant.with_tenant(account) { create(:playbook, account: account, name: "Marketing") }
      other_playbook = nil
      ActsAsTenant.with_tenant(other_account) do
        other_playbook = build(:playbook, account: other_account, name: "Marketing")
        expect(other_playbook).to be_valid
      end
    end
  end

  describe "associations" do
    it "has many playbook_versions" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        version = create(:playbook_version, playbook: playbook)
        expect(playbook.playbook_versions).to include(version)
      end
    end

    it "has many playbook_feedbacks" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        feedback = create(:playbook_feedback, account: account, playbook: playbook)
        expect(playbook.playbook_feedbacks).to include(feedback)
      end
    end

    it "has many analysis_playbooks" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account)
        competitor = create(:competitor, account: account)
        analysis = create(:analysis, account: account, competitor: competitor)
        ap = create(:analysis_playbook, analysis: analysis, playbook: playbook)
        expect(playbook.analysis_playbooks).to include(ap)
      end
    end
  end

  describe "#current_content" do
    it "returns initial_content when no version exists" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account, name: "Meu Nicho", current_version_number: 0)
        content = playbook.current_content
        expect(content).to include("Meu Nicho")
      end
    end

    it "returns latest version content when version exists" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account, current_version_number: 1)
        create(:playbook_version, playbook: playbook, version_number: 1, content: "Conteúdo da versão 1")
        expect(playbook.current_content).to include("Conteúdo da versão 1")
      end
    end
  end

  describe "#initial_content" do
    it "generates markdown with playbook name" do
      ActsAsTenant.with_tenant(account) do
        playbook = build(:playbook, account: account, name: "Marketing Imobiliário", niche: "corretores")
        content = playbook.initial_content
        expect(content).to include("Marketing Imobiliário")
        expect(content).to include("corretores")
      end
    end
  end

  describe "author_role and target_audience" do
    it "accepts nil for both fields" do
      ActsAsTenant.with_tenant(account) do
        playbook = build(:playbook, account: account, author_role: nil, target_audience: nil)
        expect(playbook).to be_valid
      end
    end

    it "rejects author_role longer than 200 characters" do
      ActsAsTenant.with_tenant(account) do
        playbook = build(:playbook, account: account, author_role: "a" * 201)
        expect(playbook).not_to be_valid
        expect(playbook.errors[:author_role]).to be_present
      end
    end

    it "accepts author_role with exactly 200 characters" do
      ActsAsTenant.with_tenant(account) do
        playbook = build(:playbook, account: account, author_role: "a" * 200)
        expect(playbook).to be_valid
      end
    end

    it "rejects target_audience longer than 200 characters" do
      ActsAsTenant.with_tenant(account) do
        playbook = build(:playbook, account: account, target_audience: "b" * 201)
        expect(playbook).not_to be_valid
        expect(playbook.errors[:target_audience]).to be_present
      end
    end

    it "strips whitespace from author_role before save" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account, author_role: "  Especialista em marketing  ")
        expect(playbook.reload.author_role).to eq("Especialista em marketing")
      end
    end

    it "strips whitespace from target_audience before save" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account, target_audience: "  Corretores de imóveis  ")
        expect(playbook.reload.target_audience).to eq("Corretores de imóveis")
      end
    end
  end

  describe "scopes" do
    it ".recent returns playbooks ordered by created_at desc" do
      ActsAsTenant.with_tenant(account) do
        old = create(:playbook, account: account, created_at: 2.days.ago)
        new_pb = create(:playbook, account: account, created_at: 1.day.ago)
        expect(Playbook.recent.first).to eq(new_pb)
        expect(Playbook.recent.last).to eq(old)
      end
    end
  end

  describe "#current_version" do
    it "returns nil when current_version_number is 0" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account, current_version_number: 0)
        expect(playbook.current_version).to be_nil
      end
    end

    it "returns the version matching current_version_number" do
      ActsAsTenant.with_tenant(account) do
        playbook = create(:playbook, account: account, current_version_number: 2)
        create(:playbook_version, playbook: playbook, version_number: 1, content: "v1")
        v2 = create(:playbook_version, playbook: playbook, version_number: 2, content: "v2")
        expect(playbook.current_version).to eq(v2)
      end
    end
  end
end
