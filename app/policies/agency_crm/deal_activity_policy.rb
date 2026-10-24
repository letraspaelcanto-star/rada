# frozen_string_literal: true

class AgencyCrm::DealActivityPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end
end
