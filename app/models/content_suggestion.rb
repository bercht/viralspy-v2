class ContentSuggestion < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :analysis
  has_many :generated_medias, dependent: :destroy

  enum :content_type, {
    reel: 0,
    carousel: 1,
    image: 2
  }, prefix: :content

  enum :status, {
    draft: 0,
    saved: 1,
    discarded: 2
  }

  validates :position,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 },
    uniqueness: { scope: :analysis_id }

  validates :content_type, presence: true

  scope :ordered, -> { order(position: :asc) }
  scope :by_content_type, ->(type) { where(content_type: type) }
end
