FactoryBot.define do
  factory :content_suggestion do
    account
    analysis { association(:analysis, account: account) }
    sequence(:position) { |n| n }
    content_type { :reel }
    hook { "3 erros que 80% dos corretores cometem" }
    caption_draft { Faker::Lorem.words(number: 15).join(' ') }
    format_details do
      { 'duration_seconds' => 30, 'structure' => %w[hook problem solution cta] }
    end
    suggested_hashtags { %w[imoveis corretor] }
    rationale { "Baseado em 5 reels de alta performance do concorrente." }
    status { :draft }

    trait :reel do
      content_type { :reel }
      format_details do
        { 'duration_seconds' => 30, 'structure' => %w[hook problem solution cta] }
      end
    end

    trait :carousel do
      content_type { :carousel }
      format_details do
        {
          'slides' => [
            { 'title' => 'Intro', 'body' => 'Hoje vou te mostrar...' },
            { 'title' => 'Dica 1', 'body' => '...' }
          ]
        }
      end
    end

    trait :image do
      content_type { :image }
      format_details do
        { 'composition_tips' => 'Foto frontal do imóvel', 'text_overlay' => 'R$ 450k' }
      end
    end

    trait :saved do
      status { :saved }
    end

    trait :discarded do
      status { :discarded }
    end
  end
end
