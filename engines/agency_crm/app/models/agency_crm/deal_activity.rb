# frozen_string_literal: true

# == Schema Information (contrato PLAN-DE-PROYECTO.md §4)
#
# Tabla: agency_deal_activities — timeline del deal.
#
class AgencyCrm::DealActivity < ApplicationRecord
  self.table_name = 'agency_deal_activities'

  belongs_to :account
  belongs_to :deal, class_name: 'AgencyCrm::Deal', foreign_key: 'agency_deal_id', inverse_of: :activities

  enum :actor_type, { user: 0, system: 1, ai: 2, automation: 3 }
  enum :kind, { note: 0, stage_change: 1, message_link: 2, task_created: 3, call: 4, email: 5, system_event: 6 }

  validates :body, presence: true
  validate :actor_id_consistency

  scope :recent, -> { order(created_at: :desc) }

  private

  def actor_id_consistency
    # actor_id solo tiene sentido con actor_type user (y a futuro ai).
    # system/automation actúan solos.
    errors.add(:actor_id, :present) if actor_id.present? && %w[system automation].include?(actor_type)
  end
end
