require 'rails_helper'

RSpec.describe "Users::Registrations", type: :request do
  describe "POST /users (signup)" do
    let(:valid_params) do
      {
        user: {
          account_name: "Imobiliária Teste",
          first_name: "João",
          last_name: "Silva",
          email: "joao@teste.com",
          password: "senha123",
          password_confirmation: "senha123"
        }
      }
    end

    context "com params válidos" do
      it "cria User e Account na mesma transação" do
        expect {
          post user_registration_path, params: valid_params
        }.to change(User, :count).by(1).and change(Account, :count).by(1)

        expect(response).to redirect_to(dashboard_path)

        user = User.last
        expect(user.email).to eq("joao@teste.com")
        expect(user.account.name).to eq("Imobiliária Teste")
      end
    end

    context "com account_name vazio" do
      it "não cria User nem Account" do
        params = valid_params.deep_merge(user: { account_name: "" })

        expect {
          post user_registration_path, params: params
        }.not_to change(User, :count)

        expect(Account.count).to eq(0)
      end
    end

    context "com email já existente" do
      before do
        existing_account = Account.create!(name: "Outra Imob")
        User.create!(
          account: existing_account,
          first_name: "Maria",
          last_name: "Santos",
          email: "joao@teste.com",
          password: "senha123"
        )
      end

      it "faz rollback completo — não cria nem Account novo nem User novo" do
        user_count_before = User.count
        account_count_before = Account.count

        post user_registration_path, params: valid_params

        expect(User.count).to eq(user_count_before)
        expect(Account.count).to eq(account_count_before)
      end
    end

    context "com senha curta" do
      it "faz rollback completo" do
        params = valid_params.deep_merge(user: { password: "123", password_confirmation: "123" })

        expect {
          post user_registration_path, params: params
        }.not_to change(User, :count)

        expect(Account.count).to eq(0)
      end
    end
  end
end
