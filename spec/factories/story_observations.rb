FactoryBot.define do
  factory :story_observation do
    association :account
    association :competitor
    observed_on { Date.today }
    format { 'video' }
    perceived_engagement { 'medium' }
    description { Faker::Lorem.words(number: 8).join(' ') }
  end
end
