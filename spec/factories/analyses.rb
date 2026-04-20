FactoryBot.define do
  factory :analysis do
    account
    competitor { association(:competitor, account: account) }
    status { :pending }
    max_posts { 50 }
    raw_data { {} }
    profile_metrics { {} }
    insights { {} }
    posts_scraped_count { 0 }
    posts_analyzed_count { 0 }

    trait :scraping do
      status { :scraping }
      started_at { 1.minute.ago }
      scraping_provider { 'apify' }
      scraping_run_id { SecureRandom.hex(8) }
    end

    trait :completed do
      status { :completed }
      started_at { 5.minutes.ago }
      finished_at { 1.minute.ago }
      scraping_provider { 'apify' }
      scraping_run_id { SecureRandom.hex(8) }
      posts_scraped_count { 30 }
      posts_analyzed_count { 16 }
      profile_metrics do
        {
          'posts_per_week' => 4.2,
          'content_mix' => { 'reel' => 0.70, 'carousel' => 0.20, 'image' => 0.10 },
          'avg_likes_per_post' => 324,
          'avg_comments_per_post' => 18
        }
      end
      insights do
        {
          'reels' => { 'hooks' => [], 'structures' => [], 'ctas' => [], 'themes' => [] },
          'carousels' => { 'structures' => [], 'themes' => [] },
          'images' => { 'caption_styles' => [], 'themes' => [] }
        }
      end
    end

    trait :failed do
      status { :failed }
      started_at { 5.minutes.ago }
      finished_at { 2.minutes.ago }
      error_message { 'Apify scraping failed: rate limit' }
    end

  end
end
