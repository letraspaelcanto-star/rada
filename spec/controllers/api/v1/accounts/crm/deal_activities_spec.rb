# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CRM Deal Activities API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }

  let!(:pipeline) { AgencyCrm::Pipeline.create!(account: account, name: 'Ventas OB') }
  let!(:stage) do
    pipeline.stages.create!(account: account, name: 'nuevo', position: 0, win_probability: 10)
  end
  let!(:deal) do
    AgencyCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, contact: contact, title: 'Silla de ruedas')
  end
  let!(:editor_membership) do
    AgencyCrm::BoardMembership.create!(account: account, pipeline: pipeline, user: agent, role: :editor)
  end

  describe 'GET /api/v1/accounts/{account.id}/crm/deals/{deal.id}/activities' do
    it 'returns the timeline ordered by created_at desc' do
      older = deal.activities.create!(account: account, kind: :note, body: 'Primera nota', actor_type: :user, actor_id: agent.id)
      newer = deal.activities.create!(account: account, kind: :call, body: 'Llamado de seguimiento', actor_type: :user, actor_id: agent.id)

      get "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/activities", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].map { |a| a['id'] }).to eq([newer.id, older.id])
      expect(response.parsed_body['payload'].first['kind']).to eq('call')
    end

    it 'returns unauthorized for unauthenticated users' do
      get "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/activities"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/crm/deals/{deal.id}/activities' do
    it 'creates a note with the authenticated user as actor' do
      expect do
        post "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/activities",
             params: { activity: { kind: :note, body: 'Pidio cotizacion por WhatsApp' } },
             headers: agent.create_new_auth_token
      end.to change(deal.activities, :count).by(1)

      activity = deal.activities.last
      expect(activity.actor_type).to eq('user')
      expect(activity.actor_id).to eq(agent.id)
      expect(response).to have_http_status(:success)
    end

    it 'creates system events without actor' do
      post "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/activities",
           params: { activity: { kind: :system_event, body: 'Webhook recibido', actor_type: :automation } },
           headers: agent.create_new_auth_token

      activity = deal.activities.last
      expect(activity.actor_type).to eq('automation')
      expect(activity.actor_id).to be_nil
    end

    it 'rejects activities without body' do
      post "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/activities",
           params: { activity: { kind: :note, body: '' } },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'account isolation' do
    let(:other_account) { create(:account) }
    let!(:other_deal) do
      other_pipeline = AgencyCrm::Pipeline.create!(account: other_account, name: 'Foreign pipeline')
      other_stage = other_pipeline.stages.create!(account: other_account, name: 'nuevo', position: 0, win_probability: 10)
      AgencyCrm::Deal.create!(account: other_account, pipeline: other_pipeline, stage: other_stage,
                              contact: create(:contact, account: other_account), title: 'Foreign deal')
    end

    it 'returns 404 for index with a deal from another account' do
      get "/api/v1/accounts/#{account.id}/crm/deals/#{other_deal.id}/activities", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for create with a deal from another account' do
      expect do
        post "/api/v1/accounts/#{account.id}/crm/deals/#{other_deal.id}/activities",
             params: { activity: { kind: :note, body: 'Intruding note' } }, headers: agent.create_new_auth_token
      end.not_to change(AgencyCrm::DealActivity, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
