FactoryBot.define do
  factory :media_generation_usage_log do
    association :account
    association :generated_media

    provider { "heygen" }
    duration_seconds { 30 }
    cost_cents { 0 }
  end
end
