FactoryBot.define do
  factory :playbook_suggestion do
    association :account
    association :playbook
    content_type { "reel" }
    hook { "Gancho de teste" }
    caption_draft { "Legenda de teste com conteúdo relevante." }
    format_details { {} }
    suggested_hashtags { ["imoveis", "corretor"] }
    rationale { "Funciona porque segue padrões do nicho." }
    status { :draft }
  end
end
