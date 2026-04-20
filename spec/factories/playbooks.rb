FactoryBot.define do
  factory :playbook do
    association :account
    sequence(:name) { |n| "Playbook #{n}" }
    niche { "marketing digital" }
    purpose { "Acumular conhecimento sobre o nicho." }
    current_version_number { 0 }

    trait :with_version do
      current_version_number { 1 }

      after(:create) do |playbook|
        create(:playbook_version, playbook: playbook, version_number: 1, content: "Conteúdo de teste v1")
      end
    end
  end

  factory :playbook_version do
    association :playbook
    sequence(:version_number) { |n| n }
    content { "# Playbook\n\nConteúdo gerado pela IA." }
    diff_summary { "Atualização inicial do playbook." }
    feedbacks_incorporated_count { 0 }
  end

  factory :playbook_feedback do
    association :account
    association :playbook
    content { "Aprendi que reels com gancho emocional performam melhor." }
    status { :pending }
    source { :manual }
  end

  factory :analysis_playbook do
    association :analysis
    association :playbook
    update_status { :playbook_update_pending }
  end
end
