class PlaybookPolicy < ApplicationPolicy
  def index?   = true
  def show?    = record.account_id == user.account_id
  def new?     = true
  def create?  = true
  def edit?    = record.account_id == user.account_id
  def update?  = record.account_id == user.account_id
  def destroy? = record.account_id == user.account_id
  def export?  = record.account_id == user.account_id
end
