# frozen_string_literal: true

# Timeline del deal (brief Sprint 3.5 ítem 5): el record es el deal padre (el
# controller autoriza con `policy_class:`); viewer lee, editor anota, admin
# de la cuenta todo.
class AgencyCrm::DealActivityPolicy < ApplicationPolicy
  include AgencyCrm::BoardAccess

  def index?
    administrator? || board_member?
  end

  def create?
    administrator? || board_editor?
  end
end
