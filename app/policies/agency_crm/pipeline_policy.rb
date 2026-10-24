# frozen_string_literal: true

class AgencyCrm::PipelinePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    @account_user.present?
  end

  def create?
    @account_user.administrator?
  end

  def reorder_stages?
    @account_user.administrator?
  end
end
