class OwnPost < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :own_profile
  belongs_to :inspired_by_suggestion,
    class_name: "ContentSuggestion",
    optional: true

  enum :post_type, {
    reel:     "reel",
    carousel: "carousel",
    image:    "image",
    story:    "story"
  }

  enum :transcript_status, {
    pending:   0,
    completed: 1,
    failed:    2,
    skipped:   3
  }

  enum :performance_rating, {
    breakthrough: 0,
    good:         1,
    average:      2,
    flop:         3
  }, prefix: :rating

  validates :post_type, presence: true
  validates :instagram_post_id, uniqueness: { scope: :own_profile_id }, allow_nil: true

  scope :recent, -> { order(posted_at: :desc) }
  scope :reels,  -> { where(post_type: :reel) }
  scope :needs_metrics_refresh, -> {
    where("metrics_last_fetched_at IS NULL OR metrics_last_fetched_at < ?", 23.hours.ago)
  }

  def engagement_rate
    metrics["engagement_rate"]
  end

  def add_metrics_snapshot(new_metrics)
    snapshot = new_metrics.merge("captured_at" => Time.current.iso8601)
    self.metrics = new_metrics
    self.metrics_history = (metrics_history || []) + [ snapshot ]
    self.metrics_last_fetched_at = Time.current
  end
end
