class ApiCredentialPolicy < ApplicationPolicy
  def show?
    record.account_id == user.account_id
  end

  def create?
    true
  end

  def update?
    record.account_id == user.account_id
  end

  def destroy?
    record.account_id == user.account_id
  end
end
