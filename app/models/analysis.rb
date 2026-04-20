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
    # index 6 reserved — previously `refining`, removed in Fase 1.5b Tarefa 3.4
    # Do NOT reuse index 6 without checking for zombie data in production.
    completed: 7,
    failed: 8
  }

  validates :max_posts, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 10,
    less_than_or_equal_to: 100
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :in_progress, -> { where(status: %i[pending scraping scoring transcribing analyzing generating_suggestions]) }

  def duration_seconds
    return nil unless started_at && finished_at

    (finished_at - started_at).to_i
  end
end
