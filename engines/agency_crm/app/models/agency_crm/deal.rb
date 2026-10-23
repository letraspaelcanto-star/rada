# frozen_string_literal: true

# == Schema Information (contrato PLAN-DE-PROYECTO.md §4)
#
# Tabla: agency_deals
#
# Invariantes:
# - stage y pipeline pertenecen al MISMO account que el deal (aislamiento por cliente).
# - priority replica el enum de Conversation: copia directa de valor, sin mapeo.
# - discarded_at: soft-delete.
#
module AgencyCrm
  class Deal < ApplicationRecord
    self.table_name = 'agency_deals'

    belongs_to :account
    belongs_to :pipeline, class_name: 'AgencyCrm::Pipeline', foreign_key: 'agency_pipeline_id', inverse_of: :deals
    belongs_to :stage, class_name: 'AgencyCrm::PipelineStage', foreign_key: 'agency_pipeline_stage_id', inverse_of: :deals
    belongs_to :contact, class_name: '::Contact', inverse_of: :agency_crm_deals
    belongs_to :conversation, class_name: '::Conversation', optional: true
    belongs_to :company, class_name: '::Company', optional: true
    belongs_to :assignee, class_name: '::User', optional: true

    has_many :activities, class_name: 'AgencyCrm::DealActivity', foreign_key: 'agency_deal_id',
             inverse_of: :deal, dependent: :destroy
    has_many :tasks, class_name: 'AgencyCrm::Task', foreign_key: 'agency_deal_id',
             inverse_of: :deal, dependent: :destroy

    enum :status, { open: 0, won: 1, lost: 2 }
    enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }

    validates :title, presence: true
    validates :value_cents, numericality: { greater_than_or_equal_to: 0 }
    validate :stage_matches_account
    validate :pipeline_matches_account

    scope :kept, -> { where(discarded_at: nil) }
    scope :discarded, -> { where.not(discarded_at: nil) }

    def discard
      update(discarded_at: Time.current)
    end

    private

    def stage_matches_account
      return if stage.blank? || account.blank?

      errors.add(:stage, :invalid) if stage.account_id != account_id
    end

    def pipeline_matches_account
      return if pipeline.blank? || account.blank?

      errors.add(:pipeline, :invalid) if pipeline.account_id != account_id
    end
  end
end
