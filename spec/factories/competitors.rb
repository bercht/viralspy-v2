FactoryBot.define do
  factory :competitor do
    association :account
    sequence(:instagram_handle) { |n| "competitor#{n}" }
    full_name { Faker::Name.name }
    bio { Faker::Lorem.words(number: 12).join(' ') }
    followers_count { rand(1_000..100_000) }
    following_count { rand(100..2_000) }
    posts_count { rand(50..500) }
    profile_pic_url { "https://example.com/pic.jpg" }
  end
end
