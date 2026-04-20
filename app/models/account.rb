class Account < ApplicationRecord
  DEFAULT_LLM_PREFERENCES = {
    "transcription_provider" => "assemblyai",
    "transcription_model" => "default",
    "analysis_provider" => "openai",
    "analysis_model" => "gpt-4o-mini",
    "generation_provider" => "anthropic",
    "generation_model" => "claude-sonnet-4-6"
  }.freeze

  has_many :users, dependent: :destroy
  has_many :competitors, dependent: :destroy
  has_many :analyses, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :content_suggestions, dependent: :destroy
  has_many :llm_usage_logs, dependent: :nullify
  has_many :transcription_usage_logs, dependent: :nullify
  has_many :api_credentials, dependent: :destroy

  validates :name, presence: true

  def llm_preferences_with_defaults
    DEFAULT_LLM_PREFERENCES.merge(llm_preferences || {})
  end

  def api_credential_for(provider)
    api_credentials.active.find_by(provider: provider.to_s)
  end
end
