# frozen_string_literal: true

# Tareas (brief Sprint 3.5 ítem 5): una tarea ligada a un deal se rige por el
# board de ese deal (editor escribe, viewer lee); una tarea suelta (sin deal)
# la puede crear cualquier miembro de algún board de la cuenta.
class AgencyCrm::TaskPolicy < ApplicationPolicy
  include AgencyCrm::BoardAccess

  def create?
    return administrator? || board_editor?(record.deal.pipeline) if record.deal.present?

    administrator? || any_board_member?
  end

  def update?
    create?
  end
end
