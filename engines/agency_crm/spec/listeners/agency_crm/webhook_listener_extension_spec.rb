# frozen_string_literal: true

require File.expand_path('../../agency_crm_spec_helper', __dir__)
require File.expand_path('../../../../../spec/rails_helper', __dir__)

RSpec.describe AgencyCrm::WebhookListenerExtension do
  let(:listener) { WebhookListener.instance }
  let(:account) { create(:account) }
  let(:pipeline) { create_agency_pipeline(account) }
  let(:stage) { create_agency_stage(pipeline, name: 'Nuevo') }
  let(:contact) { create(:contact, account: account) }
  let(:deal) do
    AgencyCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, contact: contact, title: 'Cama Centuris')
  end
  let(:changed_attributes) { { 'agency_pipeline_stage_id' => [1, 2] } }

  %w[deal_created deal_stage_changed deal_won deal_lost].each do |event_name|
    describe "##{event_name}" do
      let(:event) { Events::Base.new(event_name, Time.zone.now, deal: deal, changed_attributes: changed_attributes) }

      it 'entrega el webhook de cuenta suscripto al evento' do
        webhook = create(:webhook, account: account, inbox: nil, subscriptions: [event_name])
        expected_payload = deal.webhook_data.merge(
          event: event_name,
          changed_attributes: [{ 'agency_pipeline_stage_id' => { previous_value: 1, current_value: 2 } }]
        )

        expect(WebhookJob).to receive(:perform_later).with(
          webhook.url, expected_payload, :account_webhook, secret: webhook.secret, delivery_id: instance_of(String)
        ).once
        listener.public_send(event_name, event)
      end

      it 'no entrega si el webhook no esta suscripto al evento' do
        create(:webhook, account: account, inbox: nil, subscriptions: ['contact_created'])

        expect(WebhookJob).not_to receive(:perform_later)
        listener.public_send(event_name, event)
      end

      it 'no entrega webhooks de otra cuenta' do
        create(:webhook, account: create(:account), inbox: nil, subscriptions: [event_name])

        expect(WebhookJob).not_to receive(:perform_later)
        listener.public_send(event_name, event)
      end
    end
  end

  it 'incluye la conversacion linkeada y los custom_attributes en el payload' do
    conversation = create(:conversation, account: account, contact: contact)
    deal.update!(conversation: conversation, custom_attributes: { 'obra_social' => 'PAMI' })

    expect(deal.webhook_data).to include(
      custom_attributes: { 'obra_social' => 'PAMI' },
      conversation: conversation.webhook_data,
      stage: { id: stage.id, name: 'Nuevo', is_won: false, is_lost: false }
    )
  end
end
