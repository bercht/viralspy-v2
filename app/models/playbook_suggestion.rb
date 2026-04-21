class PlaybookSuggestion < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :playbook

  enum :status, { draft: 0, saved: 1, discarded: 2 }
  enum :content_type, { reel: "reel", carousel: "carousel", image: "image", story: "story" }

  validates :content_type, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :visible, -> { where(status: [ :draft, :saved ]) }
end
