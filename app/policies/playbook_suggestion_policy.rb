# frozen_string_literal: true

class PlaybookSuggestionPolicy < ApplicationPolicy
  def update?
    record.account == user.account
  end
end
