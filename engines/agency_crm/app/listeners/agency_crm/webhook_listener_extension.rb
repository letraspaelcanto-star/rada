# frozen_string_literal: true

# Entrega de los webhooks deal_* (Webhook::ALLOWED_WEBHOOK_EVENTS) a los webhooks
# de cuenta suscriptos, igual que contact_created/contact_updated.
#
# Se incluye en el WebhookListener de Chatwoot desde AgencyCrm::Engine: Wisper solo
# entrega un evento a los listeners que responden a su nombre, asi que sin estos
# metodos los deal_* se despachaban y nadie los recibia.
module AgencyCrm::WebhookListenerExtension
  def deal_created(event)
    deliver_deal_webhook(event, __method__)
  end

  def deal_stage_changed(event)
    deliver_deal_webhook(event, __method__)
  end

  def deal_won(event)
    deliver_deal_webhook(event, __method__)
  end

  def deal_lost(event)
    deliver_deal_webhook(event, __method__)
  end

  private

  def deliver_deal_webhook(event, event_name)
    deal = event.data[:deal]
    payload = deal.webhook_data.merge(event: event_name.to_s, changed_attributes: extract_changed_attributes(event))
    deliver_account_webhooks(payload, deal.account)
  end
end
