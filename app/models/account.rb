class Account < ApplicationRecord
  DEFAULT_LLM_PREFERENCES = {
    "transcription_provider" => "assemblyai",
    "transcription_model" => "default",
    "analysis_provider" => "openai",
    "analysis_model" => "gpt-4o-mini",
    "generation_provider" => "anthropic",
    "generation_model" => "claude-sonnet-4-6"
  }.freeze

  # Preference keys that map to a required credential for running analyses.
  # Each resolves to a provider string (e.g. "openai") that must have an
  # active ApiCredential before ready_for_analysis? returns true.
  ANALYSIS_PROVIDER_PREFERENCE_KEYS = %w[
    transcription_provider
    analysis_provider
    generation_provider
  ].freeze

  has_many :users, dependent: :destroy
  has_many :competitors, dependent: :destroy
  has_many :analyses, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :content_suggestions, dependent: :destroy
  has_many :llm_usage_logs, dependent: :nullify
  has_many :transcription_usage_logs, dependent: :nullify
  has_many :api_credentials, dependent: :destroy
  has_many :playbooks, dependent: :destroy
  has_many :playbook_feedbacks, dependent: :destroy

  validates :name, presence: true

  def llm_preferences_with_defaults
    DEFAULT_LLM_PREFERENCES.merge(llm_preferences || {})
  end

  def api_credential_for(provider)
    api_credentials.active.find_by(provider: provider.to_s)
  end

  def ready_for_analysis?
    missing_credentials_for_analysis.empty?
  end

  def missing_credentials_for_analysis
    prefs = llm_preferences_with_defaults
    providers_needed = ANALYSIS_PROVIDER_PREFERENCE_KEYS.map { |key| prefs[key] }.compact.uniq
    providers_needed.reject { |provider| api_credential_for(provider).present? }.map(&:to_sym)
  end
end
