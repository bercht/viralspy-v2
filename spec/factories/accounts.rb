FactoryBot.define do
  factory :account do
    name { Faker::Company.name }

    trait :with_credentials do
      after(:create) do |account|
        ActsAsTenant.with_tenant(account) do
          create(:api_credential, account: account, provider: "openai")
          create(:api_credential, account: account, provider: "anthropic")
          create(:api_credential, account: account, provider: "assemblyai")
        end
      end
    end
  end
end
