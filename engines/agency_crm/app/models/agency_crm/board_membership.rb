# frozen_string_literal: true

# == Schema Information (contrato PLAN-DE-PROYECTO.md §4)
#
# Tabla: agency_board_memberships — control de acceso por pipeline.
#
module AgencyCrm
  class BoardMembership < ApplicationRecord
    self.table_name = 'agency_board_memberships'

    belongs_to :account
    belongs_to :pipeline, class_name: 'AgencyCrm::Pipeline', foreign_key: 'agency_pipeline_id', inverse_of: :board_memberships
    belongs_to :user, class_name: '::User'

    enum :role, { viewer: 0, editor: 1 }

    validates :user_id, uniqueness: { scope: :agency_pipeline_id }
    validate :user_belongs_to_account

    private

    # Los agentes asignables salen de account_users (join existente), nunca de users global.
    def user_belongs_to_account
      return if user.blank? || account.blank?

      errors.add(:user, :invalid) unless account.account_users.exists?(user_id: user_id)
    end
  end
end
