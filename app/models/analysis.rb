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

  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  def duration_seconds
    return nil unless started_at && finished_at

    (finished_at - started_at).to_i
  end

  private

  def broadcast_status_change
    broadcast_replace_to(
      "analysis_#{id}",
      target: ActionView::RecordIdentifier.dom_id(self),
      partial: "analyses/analysis_body",
      locals: { analysis: self }
    )
    broadcast_replace_to(
      "competitor_#{competitor_id}_analyses",
      target: ActionView::RecordIdentifier.dom_id(self, :list_item),
      partial: "analyses/list_item",
      locals: { analysis: self, competitor: competitor }
    )
  end
end
