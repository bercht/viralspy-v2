FactoryBot.define do
  factory :user do
    association :account
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
  end
end
