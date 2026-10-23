# frozen_string_literal: true

# == Schema Information (contrato PLAN-DE-PROYECTO.md §4)
#
# Tabla: agency_tasks
#
class AgencyCrm::Task < ApplicationRecord
  self.table_name = 'agency_tasks'

  belongs_to :account
  belongs_to :deal, class_name: 'AgencyCrm::Deal', foreign_key: 'agency_deal_id', inverse_of: :tasks, optional: true
  belongs_to :conversation, class_name: '::Conversation', optional: true
  belongs_to :assignee, class_name: '::User'

  validates :title, presence: true

  scope :pending, -> { where(completed_at: nil) }
  scope :overdue, -> { pending.where('due_at < ?', Time.current) }

  def complete!
    update(completed_at: Time.current)
  end
end
