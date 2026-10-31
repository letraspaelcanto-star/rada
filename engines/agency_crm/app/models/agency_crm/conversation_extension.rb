# frozen_string_literal: true

# Borrar una conversación no puede fallar ni tirar deals/tareas (ADR 0002):
# el vínculo pasa a NULL y el histórico se conserva.
module AgencyCrm::ConversationExtension
  extend ActiveSupport::Concern

  included do
    has_many :agency_crm_deals, class_name: 'AgencyCrm::Deal', foreign_key: :conversation_id,
                                dependent: :nullify, inverse_of: :conversation
    has_many :agency_crm_tasks, class_name: 'AgencyCrm::Task', foreign_key: :conversation_id,
                                dependent: :nullify, inverse_of: :conversation
  end
end
