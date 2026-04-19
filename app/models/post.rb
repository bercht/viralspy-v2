class Post < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :analysis
  belongs_to :competitor

  enum :post_type, {
    reel: 0,
    carousel: 1,
    image: 2
  }

  enum :transcript_status, {
    pending: 0,
    completed: 1,
    failed: 2,
    skipped: 3
  }, prefix: :transcript

  validates :instagram_post_id, presence: true
  validates :post_type, presence: true

  scope :selected, -> { where(selected_for_analysis: true) }
  scope :by_type, ->(type) { where(post_type: type) }
  scope :ranked, -> { order(quality_score: :desc) }
  scope :recent_first, -> { order(posted_at: :desc) }
  scope :eligible_for_scoring, -> {
    where("likes_count + comments_count >= ? AND posted_at IS NOT NULL AND posted_at <= ?",
          10, 6.hours.ago)
  }

  def has_video?
    video_url.present?
  end
end
