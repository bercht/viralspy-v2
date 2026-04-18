FactoryBot.define do
  factory :transcription_usage_log do
    account
    provider { 'openai' }
    model { 'gpt-4o-mini-transcribe' }
    audio_duration_seconds { 45 }
    cost_cents { 1 }

    trait :with_post do
      transient do
        linked_analysis { nil }
      end

      analysis { linked_analysis || association(:analysis, account: account) }
      post { association(:post, :reel, account: account, analysis: analysis) }
    end
  end
end
