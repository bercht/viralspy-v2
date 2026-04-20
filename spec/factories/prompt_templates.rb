FactoryBot.define do
  factory :prompt_template do
    use_case { "reel_analysis" }
    sequence(:version) { |n| n }
    system_content { "You are an Instagram content analyst." }
    user_content_erb { "Analyze these <%= posts_count %> posts." }
    active { false }

    trait :active do
      active { true }
    end
  end
end
