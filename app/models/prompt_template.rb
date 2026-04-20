class PromptTemplate < ApplicationRecord
  USE_CASES = %w[reel_analysis carousel_analysis image_analysis content_suggestions].freeze

  validates :use_case, presence: true, inclusion: { in: USE_CASES }
  validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :version, uniqueness: { scope: :use_case }
  validates :system_content, :user_content_erb, presence: true
  validate :only_one_active_per_use_case

  scope :active, -> { where(active: true) }

  def self.fetch_active(use_case:)
    active.find_by(use_case: use_case) or
      raise MissingActiveTemplateError, "No active template for use_case=#{use_case}"
  end

  def render(locals = {})
    {
      system: system_content,
      user: ERB.new(user_content_erb, trim_mode: "-").result_with_hash(locals)
    }
  end

  class MissingActiveTemplateError < StandardError; end

  private

  def only_one_active_per_use_case
    return unless active?

    scope = PromptTemplate.where(use_case: use_case, active: true)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:active, "another template is already active for this use_case") if scope.exists?
  end
end
