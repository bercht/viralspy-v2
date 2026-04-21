FactoryBot.define do
  factory :own_profile do
    association :account
    sequence(:instagram_handle) { |n| "myperfil#{n}" }
    full_name { Faker::Name.name }
    bio { Faker::Lorem.words(number: 8).join(' ') }
    meta_token_expires_at { 30.days.from_now }

    trait :with_token do
      meta_access_token { 'fake_token_abc123' }
      meta_token_expires_at { 30.days.from_now }
    end

    trait :with_expired_token do
      meta_access_token { 'expired_token' }
      meta_token_expires_at { 1.day.ago }
    end

    trait :with_expiring_token do
      meta_access_token { 'expiring_token' }
      meta_token_expires_at { 3.days.from_now }
    end
  end
end
