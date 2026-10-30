# frozen_string_literal: true

# Deals (brief Sprint 3.5 ítem 5): el admin de la cuenta hace todo; el viewer
# lee (index filtrado a sus boards por el Scope); el editor crea y mueve deals
# de ese pipeline. Sin membresía no hay acceso: 403 en escritura y vacío en
# index. El CRM es herramienta de trabajo diaria — por eso el editor escribe.
class AgencyCrm::DealPolicy < ApplicationPolicy
  include AgencyCrm::BoardAccess

  class Scope < Scope
    def resolve
      return scope if user_context[:account_user]&.administrator?

      scope.joins(pipeline: :board_memberships).where(agency_board_memberships: { user_id: user.id })
    end
  end

  def index?
    administrator? || any_board_member?
  end

  def create?
    administrator? || board_editor?
  end

  def update?
    create?
  end
end
