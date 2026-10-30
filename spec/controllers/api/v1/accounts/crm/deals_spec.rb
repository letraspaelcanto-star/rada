# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CRM Deals API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }

  let!(:pipeline) do
    AgencyCrm::Pipeline.create!(account: account, name: 'Ventas OB').tap do |p|
      %w[nuevo ganado].each_with_index do |name, i|
        p.stages.create!(account: account, name: name, position: i,
                         win_probability: i * 100, is_won: name == 'ganado', is_lost: false)
      end
    end
  end
  let(:first_stage) { pipeline.stages.find_by(name: 'nuevo') }
  let(:won_stage) { pipeline.stages.find_by(name: 'ganado') }

  before do
    AgencyCrm::BoardMembership.create!(account: account, pipeline: pipeline, user: agent, role: :editor)
  end

  describe 'GET /api/v1/accounts/{account.id}/crm/deals' do
    let!(:deal_open) { create_deal(title: 'Silla de ruedas', stage: first_stage) }
    let!(:deal_won) { create_deal(title: 'Muletas premium', stage: won_stage, status: :won) }

    it 'returns unauthorized for unauthenticated users' do
      get "/api/v1/accounts/#{account.id}/crm/deals"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists deals with meta count' do
      get "/api/v1/accounts/#{account.id}/crm/deals", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['meta']['count']).to eq(2)
      expect(body['payload'].map { |d| d['id'] }).to contain_exactly(deal_open.id, deal_won.id)
    end

    it 'filters by stage_id' do
      get "/api/v1/accounts/#{account.id}/crm/deals?stage_id=#{won_stage.id}", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].map { |d| d['id'] }).to eq([deal_won.id])
    end

    it 'filters by status' do
      get "/api/v1/accounts/#{account.id}/crm/deals?status=won", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].map { |d| d['id'] }).to eq([deal_won.id])
    end

    it 'searches by title' do
      get "/api/v1/accounts/#{account.id}/crm/deals?q=muletas", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].map { |d| d['id'] }).to eq([deal_won.id])
    end

    it 'excludes soft-deleted deals' do
      deal_open.discard

      get "/api/v1/accounts/#{account.id}/crm/deals", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].map { |d| d['id'] }).not_to include(deal_open.id)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/crm/deals' do
    let(:params) do
      { deal: { title: 'Colchón antiescaras', agency_pipeline_id: pipeline.id,
                agency_pipeline_stage_id: first_stage.id, contact_id: contact.id,
                value_cents: 350_000, priority: 'high', custom_attributes: { origen: 'google_ads' } } }
    end

    it 'creates a deal linked to the conversation' do
      conversation = create(:conversation, account: account)

      expect do
        post "/api/v1/accounts/#{account.id}/crm/deals",
             params: params.deep_merge(deal: { conversation_id: conversation.id }),
             headers: agent.create_new_auth_token
      end.to change(AgencyCrm::Deal, :count).by(1)

      deal = AgencyCrm::Deal.last
      expect(deal.conversation_id).to eq(conversation.id)
      expect(deal.custom_attributes['origen']).to eq('google_ads')
      expect(response.parsed_body['payload']['id']).to eq(deal.id)
    end

    it 'rejects a contact from another account' do
      foreign_contact = create(:contact, account: create(:account))

      post "/api/v1/accounts/#{account.id}/crm/deals",
           params: params.deep_merge(deal: { contact_id: foreign_contact.id }),
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end

    it 'dispatches deal_created through the existing dispatcher' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
      expect(Rails.configuration.dispatcher).to receive(:dispatch)
        .with('deal_created', kind_of(Time), hash_including(account: account))

      post "/api/v1/accounts/#{account.id}/crm/deals", params: params, headers: agent.create_new_auth_token
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/crm/deals/{id}' do
    let!(:deal) { create_deal(title: 'Andador', stage: first_stage) }

    it 'moves the deal to another stage and dispatches deal_stage_changed' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
      expect(Rails.configuration.dispatcher).to receive(:dispatch)
        .with('deal_stage_changed', kind_of(Time), anything)

      patch "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}",
            params: { deal: { agency_pipeline_stage_id: won_stage.id } },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(deal.reload.agency_pipeline_stage_id).to eq(won_stage.id)
    end

    it 'closes the deal as won when moved to the won stage from the kanban' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      patch "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}",
            params: { deal: { agency_pipeline_stage_id: won_stage.id } },
            headers: agent.create_new_auth_token

      expect(deal.reload).to have_attributes(status: 'won', closed_on: Time.zone.today)
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with('deal_won', kind_of(Time), anything)
    end

    it 'marks the deal as won and dispatches deal_won' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
      expect(Rails.configuration.dispatcher).to receive(:dispatch)
        .with('deal_won', kind_of(Time), anything)

      patch "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}",
            params: { deal: { status: 'won', closed_on: Date.current } },
            headers: agent.create_new_auth_token

      expect(deal.reload.status).to eq('won')
    end

    it 'updates custom attributes' do
      patch "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}",
            params: { deal: { custom_attributes: { producto: 'andador_aluminio' } } },
            headers: agent.create_new_auth_token

      expect(deal.reload.custom_attributes['producto']).to eq('andador_aluminio')
    end
  end

  describe 'moving a deal across boards' do
    let!(:board_b) do
      AgencyCrm::Pipeline.create!(account: account, name: 'Soporte post-venta').tap do |p|
        p.stages.create!(account: account, name: 'nuevo', position: 0, win_probability: 10)
      end
    end
    let(:board_b_stage) { board_b.stages.first }
    let(:mover) { create(:user, account: account, role: :agent) }

    before do
      AgencyCrm::BoardMembership.create!(account: account, pipeline: pipeline, user: mover, role: :viewer)
      AgencyCrm::BoardMembership.create!(account: account, pipeline: board_b, user: mover, role: :editor)
    end

    it 'forbids moving a deal out of a board where the agent is only a viewer' do
      deal_on_a = create_deal(title: 'Deal en board A', stage: first_stage)

      patch "/api/v1/accounts/#{account.id}/crm/deals/#{deal_on_a.id}",
            params: { deal: { agency_pipeline_id: board_b.id, agency_pipeline_stage_id: board_b_stage.id } },
            headers: mover.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
      expect(deal_on_a.reload.agency_pipeline_id).to eq(pipeline.id)
    end
  end

  describe 'account isolation' do
    let(:other_account) { create(:account) }
    let(:other_contact) { create(:contact, account: other_account) }
    let!(:other_pipeline) do
      AgencyCrm::Pipeline.create!(account: other_account, name: 'Foreign pipeline').tap do |p|
        p.stages.create!(account: other_account, name: 'nuevo', position: 0, win_probability: 10)
      end
    end
    let(:other_stage) { other_pipeline.stages.first }
    let!(:other_deal) do
      AgencyCrm::Deal.create!(account: other_account, pipeline: other_pipeline, stage: other_stage,
                              contact: other_contact, title: 'Foreign wheelchair deal')
    end
    let!(:own_deal) { create_deal(title: 'Own deal', stage: first_stage) }

    it 'does not list deals from other accounts' do
      get "/api/v1/accounts/#{account.id}/crm/deals", headers: agent.create_new_auth_token

      ids = response.parsed_body['payload'].map { |d| d['id'] }
      expect(ids).to include(own_deal.id)
      expect(ids).not_to include(other_deal.id)
    end

    it 'returns nothing when filtering by a stage from another account' do
      get "/api/v1/accounts/#{account.id}/crm/deals?stage_id=#{other_stage.id}", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].map { |d| d['id'] }).not_to include(other_deal.id)
    end

    it 'does not find deals from other accounts when searching' do
      get "/api/v1/accounts/#{account.id}/crm/deals?q=wheelchair", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].map { |d| d['id'] }).not_to include(other_deal.id)
    end

    it 'returns 404 for update with a deal from another account' do
      patch "/api/v1/accounts/#{account.id}/crm/deals/#{other_deal.id}",
            params: { deal: { title: 'Hijacked' } }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:not_found)
      expect(other_deal.reload.title).to eq('Foreign wheelchair deal')
    end
  end

  def create_deal(title:, stage:, status: :open)
    AgencyCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, contact: contact,
                            title: title, status: status)
  end
end
