class PlaybookVersion < ApplicationRecord
  acts_as_tenant :account
  belongs_to :account
  belongs_to :playbook
  belongs_to :triggered_by_analysis, class_name: "Analysis", foreign_key: :triggered_by_analysis_id, optional: true

  validates :content, presence: true
  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :version_number, uniqueness: { scope: :playbook_id }

  scope :recent, -> { order(version_number: :desc) }
end
