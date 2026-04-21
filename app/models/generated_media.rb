class GeneratedMedia < ApplicationRecord
  self.table_name = "generated_medias"

  acts_as_tenant :account

  belongs_to :account
  belongs_to :content_suggestion
  has_many :media_generation_usage_logs, dependent: :destroy

  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  enum :media_type, {
    avatar_video: 0
  }

  enum :provider, {
    heygen: "heygen"
  }, prefix: :provider

  validates :provider, presence: true
  validates :media_type, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_suggestion, ->(suggestion) { where(content_suggestion: suggestion) }
end
