class Competitor < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account

  validates :instagram_handle,
    presence: true,
    format: { with: /\A[a-zA-Z0-9_.]{1,30}\z/ },
    uniqueness: { scope: :account_id, case_sensitive: false }

  before_validation :normalize_handle

  scope :recent, -> { order(created_at: :desc) }

  private

  def normalize_handle
    self.instagram_handle = instagram_handle.to_s.strip.sub(/\A@/, '').downcase
  end
end
