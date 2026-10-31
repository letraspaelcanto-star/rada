# frozen_string_literal: true

# Borrar un usuario no puede fallar por deals/tareas asignados ni dejar
# membresías de board huérfanas (ADR 0002): las asignaciones pasan a NULL y
# las membresías se destruyen con el usuario.
module AgencyCrm::UserExtension
  extend ActiveSupport::Concern

  included do
    has_many :agency_crm_deals, class_name: 'AgencyCrm::Deal', foreign_key: :assignee_id,
                                dependent: :nullify, inverse_of: :assignee
    has_many :agency_crm_tasks, class_name: 'AgencyCrm::Task', foreign_key: :assignee_id,
                                dependent: :nullify, inverse_of: :assignee
    has_many :agency_crm_board_memberships, class_name: 'AgencyCrm::BoardMembership', foreign_key: :user_id,
                                            dependent: :destroy, inverse_of: :user
  end
end
