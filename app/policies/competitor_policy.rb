class CompetitorPolicy < ApplicationPolicy
  def show?
    record.account_id == user.account_id
  end

  def new?
    create?
  end

  def create?
    user.present?
  end

  def destroy?
    record.account_id == user.account_id
  end

  def update?
    record.account_id == user.account_id
  end
end
