class ApiCredential < ApplicationRecord
  acts_as_tenant :account

  encrypts :encrypted_api_key

  PROVIDERS = %w[openai anthropic assemblyai].freeze

  enum :provider, { openai: "openai", anthropic: "anthropic", assemblyai: "assemblyai" }, prefix: :provider

  enum :last_validation_status, {
    unknown: 0,
    verified: 1,
    failed: 2,
    quota_exceeded: 3
  }, prefix: :validation

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :encrypted_api_key, presence: true
  validates :account_id, uniqueness: { scope: :provider }

  scope :active, -> { where(active: true) }

  def api_key
    encrypted_api_key
  end

  def api_key=(value)
    self.encrypted_api_key = value if value.present?
  end
end
