require "rails_helper"

RSpec.describe "Playbooks", type: :request, skip_tenant: true do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:other_account) { create(:account) }

  before { sign_in user }

  describe "GET /playbooks" do
    it "retorna 200" do
      get playbooks_path
      expect(response).to have_http_status(:ok)
    end

    it "lista playbooks do tenant" do
      pb = ActsAsTenant.with_tenant(account) { create(:playbook, account: account) }
      get playbooks_path
      expect(response.body).to include(pb.name)
    end

    it "não lista playbooks de outra account" do
      other = ActsAsTenant.with_tenant(other_account) { create(:playbook, account: other_account) }
      get playbooks_path
      expect(response.body).not_to include(other.name)
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        get playbooks_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /playbooks/:id" do
    let!(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

    it "retorna 200" do
      get playbook_path(playbook)
      expect(response).to have_http_status(:ok)
    end

    it "mostra o nome do playbook" do
      get playbook_path(playbook)
      expect(response.body).to include(playbook.name)
    end

    it "retorna 404 para playbook de outra account" do
      other = ActsAsTenant.with_tenant(other_account) { create(:playbook, account: other_account) }
      get playbook_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /playbooks/new" do
    it "retorna 200" do
      get new_playbook_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /playbooks" do
    it "cria um playbook e redireciona" do
      expect {
        post playbooks_path, params: { playbook: { name: "Novo Playbook", niche: "fitness", purpose: "aprender" } }
      }.to change { Playbook.unscoped.count }.by(1)
      expect(response).to redirect_to(playbook_path(Playbook.unscoped.last))
    end

    it "rerenderiza new com dados inválidos" do
      post playbooks_path, params: { playbook: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /playbooks/:id/edit" do
    let!(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

    it "retorna 200" do
      get edit_playbook_path(playbook)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /playbooks/:id" do
    let!(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

    it "atualiza e redireciona" do
      patch playbook_path(playbook), params: { playbook: { name: "Nome Atualizado" } }
      expect(response).to redirect_to(playbook_path(playbook))
      expect(playbook.reload.name).to eq("Nome Atualizado")
    end
  end

  describe "DELETE /playbooks/:id" do
    let!(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

    it "remove o playbook e redireciona" do
      expect {
        delete playbook_path(playbook)
      }.to change { Playbook.unscoped.count }.by(-1)
      expect(response).to redirect_to(playbooks_path)
    end
  end

  describe "GET /playbooks/:id/export" do
    let!(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, :with_version, account: account) } }

    it "retorna arquivo markdown" do
      get export_playbook_path(playbook)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/markdown")
    end

    it "redireciona se não há versão" do
      pb = ActsAsTenant.with_tenant(account) { create(:playbook, account: account, current_version_number: 0) }
      get export_playbook_path(pb)
      expect(response).to redirect_to(playbook_path(pb))
    end
  end

  describe "GET /playbooks/:id/export_top_posts" do
    let!(:playbook) { ActsAsTenant.with_tenant(account) { create(:playbook, account: account) } }

    it "retorna 200 com Content-Type text/plain" do
      get export_top_posts_playbook_path(playbook)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/plain")
    end

    it "inclui Content-Disposition attachment com filename parametrizado" do
      get export_top_posts_playbook_path(playbook)
      disposition = response.headers["Content-Disposition"]
      expect(disposition).to include("attachment")
      expect(disposition).to include(playbook.name.parameterize)
    end

    it "retorna 404 para playbook de outro tenant" do
      other = ActsAsTenant.with_tenant(other_account) { create(:playbook, account: other_account) }
      get export_top_posts_playbook_path(other)
      expect(response).to have_http_status(:not_found)
    end

    context "sem login" do
      before { sign_out user }

      it "redireciona para sign_in" do
        get export_top_posts_playbook_path(playbook)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
