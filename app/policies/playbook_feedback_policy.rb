class PlaybookFeedbackPolicy < ApplicationPolicy
  def create?      = record.playbook.account_id == user.account_id
  def update?      = record.account_id == user.account_id
  def incorporate? = update?
  def dismiss?     = update?
end
