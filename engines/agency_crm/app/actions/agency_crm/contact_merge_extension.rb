# frozen_string_literal: true

# Merge de contactos con deals (ADR 0002 / brief Sprint 3.5 ítem 9): los deals
# del contacto que se van pasan al que queda ANTES de que ContactMergeAction lo
# destruya. Hoy el merge entero falla: el dependent: :nullify de Contact choca
# con agency_deals.contact_id NOT NULL. Dos deals abiertos en el mismo pipeline
# no se fusionan solos: quedan los dos, marcados con una actividad de sistema,
# y una tarea pide revisarlos.
module AgencyCrm::ContactMergeExtension
  DUPLICATE_NOTE = 'Duplicado por merge de contactos: revisar'
  DUPLICATE_TASK_TITLE = 'Revisar deals duplicados por merge de contactos'

  def perform
    # Mismo early-return que el upstream: no hay nada que mover.
    return @base_contact if @base_contact.id == @mergee_contact.id

    # Todo dentro de la transacción del merge: si algo falla, los deals vuelven
    # a donde estaban (la transacción interna de super se anida a esta).
    ActiveRecord::Base.transaction do
      move_agency_crm_deals
      super
    end
  end

  private

  def move_agency_crm_deals
    @mergee_contact.agency_crm_deals.where(account_id: @account.id).find_each do |deal|
      collision = open_deal_collision(deal)
      move_deal(deal)
      flag_merge_duplicate(deal, collision) if collision
    end
  end

  # El deal abierto del contacto base que ya ocupa ese pipeline, si existe.
  # Se calcula antes de mover el deal, contra los deals que el base ya tenía.
  def open_deal_collision(deal)
    return nil unless deal.open? && deal.discarded_at.nil?

    @base_contact.agency_crm_deals.where(account_id: @account.id)
                 .kept.open.find_by(agency_pipeline_id: deal.agency_pipeline_id)
  end

  # Sin callbacks a propósito: el traslado no es un evento de negocio del deal
  # (no despacha webhook ni saca la tarjeta del kanban).
  def move_deal(deal)
    deal.update_columns(contact_id: @base_contact.id, updated_at: Time.current)
  end

  def flag_merge_duplicate(deal, other_deal)
    [deal, other_deal].each do |duplicate|
      duplicate.activities.create!(account: duplicate.account, kind: :system_event, actor_type: :system,
                                   body: DUPLICATE_NOTE)
    end
    newer = [deal, other_deal].max_by(&:created_at)
    newer.tasks.create!(account: newer.account, assignee: newer.assignee, title: DUPLICATE_TASK_TITLE)
  end
end
