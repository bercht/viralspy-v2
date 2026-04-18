FactoryBot.define do
  factory :post do
    account
    competitor { association(:competitor, account: account) }
    analysis { association(:analysis, account: account, competitor: competitor) }
    sequence(:instagram_post_id) { |n| "post_ig_#{n}" }
    sequence(:shortcode) { |n| "ABC#{n}XYZ" }
    post_type { :reel }
    caption { Faker::Lorem.words(number: 10).join(' ') }
    display_url { "https://example.com/display_#{SecureRandom.hex(4)}.jpg" }
    likes_count { rand(50..500) }
    comments_count { rand(5..50) }
    hashtags { %w[imoveis corretor casapropria] }
    mentions { [] }
    posted_at { rand(1..30).days.ago }
    selected_for_analysis { false }
    transcript_status { :pending }

    trait :reel do
      post_type { :reel }
      video_url { "https://example.com/video_#{SecureRandom.hex(4)}.mp4" }
      video_view_count { rand(500..5_000) }
    end

    trait :carousel do
      post_type { :carousel }
      video_url { nil }
    end

    trait :image do
      post_type { :image }
      video_url { nil }
    end

    trait :selected do
      selected_for_analysis { true }
      quality_score { rand(100.0..1_000.0).round(4) }
    end

    trait :with_transcript do
      post_type { :reel }
      video_url { "https://example.com/video.mp4" }
      transcript { Faker::Lorem.words(number: 20).join(' ') }
      transcript_status { :completed }
      transcribed_at { 1.hour.ago }
    end

    trait :transcript_failed do
      post_type { :reel }
      video_url { "https://example.com/video.mp4" }
      transcript_status { :failed }
    end

    trait :transcript_skipped do
      transcript_status { :skipped }
    end
  end
end
