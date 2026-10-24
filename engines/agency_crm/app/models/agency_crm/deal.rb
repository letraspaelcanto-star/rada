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
class AgencyCrm::Deal < ApplicationRecord
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

  after_create :dispatch_deal_created
  after_update :dispatch_deal_updates

  # Tiempo real del kanban (PLAN-DE-PROYECTO.md §5): se publica SOLO tras commit,
  # en el stream pipeline:<account_id>:<pipeline_id>.
  after_create_commit :broadcast_deal_created
  after_update_commit :broadcast_deal_updates

  def discard
    update(discarded_at: Time.current)
  end

  private

  def dispatch_deal_created
    dispatch_crm_event('deal_created')
  end

  def dispatch_deal_updates
    dispatch_crm_event('deal_stage_changed', saved_changes) if saved_change_to_agency_pipeline_stage_id?
    dispatch_crm_event('deal_won', saved_changes) if saved_change_to_status? && won?
    dispatch_crm_event('deal_lost', saved_changes) if saved_change_to_status? && lost?
  end

  def broadcast_deal_created
    broadcast_deal('deal.created')
  end

  def broadcast_deal_updates
    broadcast_deal('deal.updated')
    # Si el deal cambió de pipeline, la tarjeta debe desaparecer del board viejo.
    return unless saved_change_to_agency_pipeline_id?

    previous_pipeline_id = saved_change_to_agency_pipeline_id.first
    return unless previous_pipeline_id

    ActionCable.server.broadcast(
      "pipeline:#{account_id}:#{previous_pipeline_id}",
      { event: 'deal.removed', data: { account_id: account_id, id: id, pipeline_id: previous_pipeline_id } }
    )
  end

  def broadcast_deal(event_name)
    ActionCable.server.broadcast("pipeline:#{account_id}:#{agency_pipeline_id}", {
                                   event: event_name,
                                   data: { account_id: account_id, **cable_payload }
                                 })
  end

  # Mismo shape que app/views/api/v1/models/_crm_deal.json.jbuilder para que
  # el store del kanban trate igual REST y cable.
  CABLE_PAYLOAD_ATTRIBUTES = %w[
    title status priority value_cents currency
    contact_id conversation_id company_id assignee_id
    expected_close_on closed_on lost_reason
    custom_attributes discarded_at created_at updated_at
  ].freeze

  def cable_payload
    { id: id, pipeline_id: agency_pipeline_id, stage_id: agency_pipeline_stage_id }
      .merge!(attributes.slice(*CABLE_PAYLOAD_ATTRIBUTES))
  end

  # Webhooks hacia afuera (n8n): se emite por el dispatcher existente de Chatwoot,
  # igual que Conversation — no hay bus paralelo (PLAN-DE-PROYECTO.md §5).
  def dispatch_crm_event(event_name, changed_attributes = nil)
    payload = { account: account, deal: self, changed_attributes: changed_attributes, performed_by: Current.executed_by }
    Rails.configuration.dispatcher.dispatch(event_name, Time.zone.now, **payload)
  end

  def stage_matches_account
    return if stage.blank? || account.blank?

    errors.add(:stage, :invalid) if stage.account_id != account_id
  end

  def pipeline_matches_account
    return if pipeline.blank? || account.blank?

    errors.add(:pipeline, :invalid) if pipeline.account_id != account_id
  end
end
