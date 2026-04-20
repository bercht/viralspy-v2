class AnalysisPolicy < ApplicationPolicy
  def show?
    record.account_id == user.account_id
  end

  def new?
    record.account_id == user.account_id
  end

  def create?
    record.account_id == user.account_id
  end

  def destroy?
    record.account_id == user.account_id
  end
end
