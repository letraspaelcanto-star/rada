# frozen_string_literal: true

# Acceso por board (brief Sprint 3.5 ítem 5): las policies del CRM deciden con
# `BoardMembership` — el admin de la cuenta siempre entra; `editor` escribe;
# `viewer` lee. Sin membresía el board no existe para el agente.
module AgencyCrm::BoardAccess
  private

  def administrator?
    @account_user&.administrator?
  end

  def board_member?(pipeline = record_pipeline)
    membership_for(pipeline).present?
  end

  def board_editor?(pipeline = record_pipeline)
    membership_for(pipeline)&.editor? || false
  end

  def any_board_member?
    AgencyCrm::BoardMembership.exists?(account_id: account.id, user_id: user.id)
  end

  # En checks con la clase (index/create de before_action) no hay instancia:
  # se evalúa nil y cada método cae en su alternativa.
  def record_pipeline
    record.pipeline if record.respond_to?(:pipeline) && !record.is_a?(Class)
  end

  def membership_for(pipeline)
    return nil if pipeline.blank?

    pipeline.board_memberships.find_by(user_id: user.id)
  end
end
