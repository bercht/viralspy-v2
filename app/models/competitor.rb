class Competitor < ApplicationRecord
  NICHE_FALLBACK = "conteúdo de Instagram em português brasileiro"

  acts_as_tenant :account

  belongs_to :account

  validates :instagram_handle,
    presence: true,
    format: { with: /\A[a-zA-Z0-9_.]{1,30}\z/ },
    uniqueness: { scope: :account_id, case_sensitive: false }

  validates :niche, length: { maximum: 120 }, allow_blank: true

  before_validation :normalize_handle, :strip_niche

  has_many :analyses, dependent: :destroy
  has_many :story_observations, dependent: :destroy

  scope :recent, -> { order(created_at: :desc) }

  def niche_for_prompt(analysis: nil)
    return niche.strip if niche.present?

    if analysis
      playbook_niche = analysis.analysis_playbooks
                               .order(:created_at)
                               .joins(:playbook)
                               .pick("playbooks.niche")
      return playbook_niche if playbook_niche.present?
    end

    NICHE_FALLBACK
  end

  private

  def normalize_handle
    self.instagram_handle = instagram_handle.to_s.strip.sub(/\A@/, "").downcase
  end

  def strip_niche
    self.niche = niche.strip if niche.present?
  end
end
