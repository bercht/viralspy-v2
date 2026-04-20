class AnalysisPlaybook < ApplicationRecord
  belongs_to :analysis
  belongs_to :playbook

  validates :playbook_id, uniqueness: { scope: :analysis_id }

  enum :update_status, {
    playbook_update_pending: 0,
    playbook_update_completed: 1,
    playbook_update_failed: 2
  }

  scope :playbook_update_pending, -> { where(update_status: :playbook_update_pending) }
end
