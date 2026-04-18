class LLMUsageLog < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :analysis, optional: true

  validates :provider, presence: true
  validates :model, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_use_case, ->(uc) { where(use_case: uc) }
end
