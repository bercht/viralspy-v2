class ContentSuggestionPolicy < ApplicationPolicy
  def update?
    record.account_id == user.account_id
  end
end
