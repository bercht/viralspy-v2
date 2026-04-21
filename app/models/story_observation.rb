class StoryObservation < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :competitor

  FORMATS = %w[poll quiz link video image text countdown].freeze
  PERCEIVED_ENGAGEMENTS = %w[high medium low].freeze

  validates :observed_on, presence: true
  validates :format, inclusion: { in: FORMATS }, allow_nil: true
  validates :perceived_engagement,
    inclusion: { in: PERCEIVED_ENGAGEMENTS }, allow_nil: true

  scope :recent, -> { order(observed_on: :desc) }
  scope :for_competitor, ->(competitor) { where(competitor: competitor) }
end
