class TranscriptionUsageLog < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :analysis, optional: true
  belongs_to :post, optional: true

  validates :provider, presence: true
  validates :model, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
