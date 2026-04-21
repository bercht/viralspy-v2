FactoryBot.define do
  factory :generated_media do
    association :account
    association :content_suggestion

    provider { "heygen" }
    media_type { :avatar_video }
    status { :pending }
    provider_params { { "avatar_id" => "default_avatar", "voice_id" => "default_voice" } }

    trait :processing do
      status { :processing }
      provider_job_id { "heygen_job_abc123" }
      started_at { 1.minute.ago }
    end

    trait :completed do
      status { :completed }
      provider_job_id { "heygen_job_abc123" }
      output_url { "https://resource.heygen.com/video/abc123.mp4" }
      duration_seconds { 30 }
      cost_cents { 0 }
      started_at { 2.minutes.ago }
      finished_at { 1.minute.ago }
    end

    trait :failed do
      status { :failed }
      provider_job_id { "heygen_job_abc123" }
      error_message { "Avatar not found" }
      started_at { 1.minute.ago }
      finished_at { 30.seconds.ago }
    end
  end
end
