FactoryBot.define do
  factory :own_post do
    association :account
    association :own_profile
    post_type { 'reel' }
    sequence(:instagram_post_id) { |n| "ig_post_#{n}" }
    permalink { "https://www.instagram.com/p/abc123/" }
    caption { Faker::Lorem.words(number: 8).join(' ') }
    posted_at { 7.days.ago }
    metrics { {} }
    metrics_history { [] }
    transcript_status { :pending }
  end
end
