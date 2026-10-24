# frozen_string_literal: true

class AgencyCrm::TaskPolicy < ApplicationPolicy
  def create?
    true
  end

  def update?
    true
  end
end
