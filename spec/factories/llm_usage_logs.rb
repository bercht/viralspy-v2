FactoryBot.define do
  factory :llm_usage_log do
    association :account
    provider { 'openai' }
    model { 'gpt-4o-mini' }
    use_case { 'reel_analysis' }
    prompt_tokens { 1_500 }
    completion_tokens { 400 }
    cost_cents { 3 }

    trait :anthropic do
      provider { 'anthropic' }
      model { 'claude-3-5-sonnet' }
    end

    trait :with_analysis do
      analysis { association(:analysis, account: account) }
    end
  end
end
