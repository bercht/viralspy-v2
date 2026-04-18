class Analysis < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :competitor
  has_many :posts, dependent: :destroy
  has_many :content_suggestions, dependent: :destroy
  has_many :llm_usage_logs, dependent: :nullify
  has_many :transcription_usage_logs, dependent: :nullify

  enum :status, {
    pending: 0,
    scraping: 1,
    scoring: 2,
    transcribing: 3,
    analyzing: 4,
    generating_suggestions: 5,
    completed: 6,
    failed: 7
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :in_progress, -> { where(status: %i[pending scraping scoring transcribing analyzing generating_suggestions]) }

  def duration_seconds
    return nil unless started_at && finished_at

    (finished_at - started_at).to_i
  end
end
