# frozen_string_literal: true

# Boards del kanban (brief Sprint 3.5 ítem 5): el admin de la cuenta ve todo;
# agente con membresía lee (viewer) y agente sin membresía no ve el board —
# el index lo filtra (Scope) y show responde 404, no 403, para no revelar
# que el board existe. Crear y reordenar etapas siguen siendo de admin.
class AgencyCrm::PipelinePolicy < ApplicationPolicy
  include AgencyCrm::BoardAccess

  class Scope < Scope
    def resolve
      return scope if user_context[:account_user]&.administrator?

      scope.joins(:board_memberships).where(agency_board_memberships: { user_id: user.id })
    end
  end

  def index?
    true
  end

  def show?
    return true if administrator?
    raise ActiveRecord::RecordNotFound, 'AgencyCrm::Pipeline' unless board_member?(record)

    true
  end

  def create?
    administrator?
  end

  def reorder_stages?
    administrator?
  end
end
