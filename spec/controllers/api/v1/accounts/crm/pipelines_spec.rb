# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CRM Pipelines API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  let!(:pipeline) do
    AgencyCrm::Pipeline.create!(account: account, name: 'Ventas OB').tap do |p|
      %w[nuevo contactado ganado].each_with_index do |name, i|
        p.stages.create!(account: account, name: name, position: i,
                         win_probability: i * 50, is_won: name == 'ganado', is_lost: false)
      end
    end
  end

  before do
    AgencyCrm::BoardMembership.create!(account: account, pipeline: pipeline, user: agent, role: :viewer)
  end

  describe 'GET /api/v1/accounts/{account.id}/crm/pipelines' do
    it 'returns unauthorized for unauthenticated users' do
      get "/api/v1/accounts/#{account.id}/crm/pipelines"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists pipelines of the account with stage counts' do
      get "/api/v1/accounts/#{account.id}/crm/pipelines", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].map { |p| p['id'] }).to include(pipeline.id)
      expect(response.parsed_body['payload'].first['stages_count']).to eq(3)
    end

    it 'does not leak pipelines from other accounts' do
      other_account = create(:account)
      other_pipeline = AgencyCrm::Pipeline.create!(account: other_account, name: 'Otro board')

      get "/api/v1/accounts/#{account.id}/crm/pipelines", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].map { |p| p['id'] }).not_to include(other_pipeline.id)
    end

    it 'hides every pipeline from agents without membership in any board' do
      outsider = create(:user, account: account, role: :agent)

      get "/api/v1/accounts/#{account.id}/crm/pipelines", headers: outsider.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']).to eq([])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/crm/pipelines' do
    let(:params) { { pipeline: { name: 'Soporte post-venta' } } }

    it 'creates a pipeline for administrators' do
      expect do
        post "/api/v1/accounts/#{account.id}/crm/pipelines", params: params, headers: admin.create_new_auth_token
      end.to change(AgencyCrm::Pipeline, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']['name']).to eq('Soporte post-venta')
    end

    it 'forbids non-administrators' do
      expect do
        post "/api/v1/accounts/#{account.id}/crm/pipelines", params: params, headers: agent.create_new_auth_token
      end.not_to change(AgencyCrm::Pipeline, :count)

      # El CRM renderiza la denegación de policy como 403 (Api::V1::Accounts::Crm::Authorizable);
      # 401 queda reservado para no autenticado.
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/crm/pipelines/{id}' do
    it 'returns the board with stages and deals grouped' do
      stage = pipeline.stages.first
      contact = create(:contact, account: account)
      deal = AgencyCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, contact: contact, title: 'Silla de ruedas X')

      get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body['payload']
      expect(body['stages'].map { |s| s['id'] }).to eq(pipeline.stages.order(position: :asc).map(&:id))
      stage_json = body['stages'].find { |s| s['id'] == stage.id }
      expect(stage_json['deals'].map { |d| d['id'] }).to include(deal.id)
    end

    it 'returns 404 for agents without membership (el board no existe para ellos)' do
      outsider = create(:user, account: account, role: :agent)

      get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}", headers: outsider.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/crm/pipelines/{id}/stages/reorder' do
    it 'reorders stages by stage_ids' do
      reversed = pipeline.stages.order(position: :asc).map(&:id).reverse

      patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/reorder",
            params: { stage_ids: reversed }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(pipeline.stages.order(position: :asc).map(&:id)).to eq(reversed)
    end

    it 'rejects an incomplete stage_ids list' do
      only_one = [pipeline.stages.first.id]

      patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/reorder",
            params: { stage_ids: only_one }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'forbids non-administrators' do
      reversed = pipeline.stages.order(position: :asc).map(&:id).reverse

      patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/reorder",
            params: { stage_ids: reversed }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'account isolation' do
    let(:other_account) { create(:account) }
    let!(:other_pipeline) { AgencyCrm::Pipeline.create!(account: other_account, name: 'Foreign board') }

    it 'returns 404 for show with a pipeline from another account' do
      get "/api/v1/accounts/#{account.id}/crm/pipelines/#{other_pipeline.id}", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for stages/reorder with a pipeline from another account' do
      patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{other_pipeline.id}/stages/reorder",
            params: { stage_ids: [1, 2] }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end
  end
end
