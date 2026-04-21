class OwnProfile < ApplicationRecord
  acts_as_tenant :account

  encrypts :meta_access_token

  belongs_to :account
  has_many :own_posts, dependent: :destroy

  validates :instagram_handle, presence: true,
    uniqueness: { scope: :account_id, case_sensitive: false }

  before_validation :normalize_handle

  scope :with_valid_token, -> {
    where.not(meta_access_token: nil)
         .where('meta_token_expires_at > ?', Time.current)
  }

  scope :expiring_soon, -> {
    where('meta_token_expires_at < ?', 7.days.from_now)
         .where('meta_token_expires_at > ?', Time.current)
  }

  def token_valid?
    meta_access_token.present? && meta_token_expires_at&.future?
  end

  def token_expiring_soon?
    meta_token_expires_at.present? && meta_token_expires_at < 7.days.from_now
  end

  private

  def normalize_handle
    self.instagram_handle = instagram_handle.to_s.strip.delete('@').downcase
  end
end
