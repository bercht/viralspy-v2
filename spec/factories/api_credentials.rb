FactoryBot.define do
  factory :api_credential do
    association :account
    provider { "openai" }
    encrypted_api_key { "sk-test-#{SecureRandom.hex(16)}" }
    active { true }
    last_validation_status { :unknown }

    trait :valid do
      last_validation_status { :verified }
      last_validated_at { Time.current }
    end

    trait :invalid do
      last_validation_status { :failed }
      last_validated_at { Time.current }
    end

    trait :quota_exceeded do
      last_validation_status { :quota_exceeded }
      last_validated_at { Time.current }
    end

    trait :inactive do
      active { false }
    end

    trait :openai do
      provider { "openai" }
    end

    trait :anthropic do
      provider { "anthropic" }
      encrypted_api_key { "sk-ant-test-#{SecureRandom.hex(16)}" }
    end

    trait :assemblyai do
      provider { "assemblyai" }
      encrypted_api_key { SecureRandom.hex(16) }
    end
  end
end
