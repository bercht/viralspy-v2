# frozen_string_literal: true

class PlaybookSuggestionPolicy < ApplicationPolicy
  def create?
    true  # acesso controlado pelo tenant scoping em set_playbook
  end

  def update?
    record.account == user.account
  end
end
