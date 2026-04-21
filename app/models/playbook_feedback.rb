class PlaybookFeedback < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :playbook

  validates :content, presence: true

  enum :status, {
    pending: 0,
    incorporated: 1,
    dismissed: 2
  }, prefix: :status

  enum :source, {
    manual: "manual",
    auto: "auto"
  }, prefix: :source

  scope :status_pending_scope, -> { where(status: :pending) }

  def self.pending_for_playbook(playbook)
    where(playbook: playbook, status: :pending)
  end
end
