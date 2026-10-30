# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CRM Tasks API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }

  let!(:pipeline) { AgencyCrm::Pipeline.create!(account: account, name: 'Ventas OB') }
  let!(:stage) { pipeline.stages.create!(account: account, name: 'nuevo', position: 0, win_probability: 10) }
  let!(:deal) do
    AgencyCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, contact: contact, title: 'Silla de ruedas')
  end

  describe 'POST /api/v1/accounts/{account.id}/crm/tasks' do
    it 'creates a task assigned to the authenticated user by default' do
      expect do
        post "/api/v1/accounts/#{account.id}/crm/tasks",
             params: { task: { title: 'Llamar mañana 10am', agency_deal_id: deal.id, due_at: 1.day.from_now } },
             headers: agent.create_new_auth_token
      end.to change(AgencyCrm::Task, :count).by(1)

      task = AgencyCrm::Task.last
      expect(task.assignee_id).to eq(agent.id)
      expect(task.agency_deal_id).to eq(deal.id)
      expect(response.parsed_body['payload']['id']).to eq(task.id)
    end

    it 'returns unauthorized for unauthenticated users' do
      post "/api/v1/accounts/#{account.id}/crm/tasks", params: { task: { title: 'X' } }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects tasks without title' do
      post "/api/v1/accounts/#{account.id}/crm/tasks",
           params: { task: { title: '' } },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/crm/tasks/{id}' do
    let!(:task) { AgencyCrm::Task.create!(account: account, deal: deal, assignee: agent, title: 'Enviar cotización') }

    it 'completes the task' do
      patch "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}",
            params: { task: { completed_at: Time.current } },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(task.reload.completed_at).not_to be_nil
    end

    it 'reassigns to another account agent' do
      other_agent = create(:user, account: account, role: :agent)

      patch "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}",
            params: { task: { assignee_id: other_agent.id } },
            headers: agent.create_new_auth_token

      expect(task.reload.assignee_id).to eq(other_agent.id)
    end
  end

  describe 'account isolation' do
    let(:other_account) { create(:account) }
    let(:other_agent) { create(:user, account: other_account, role: :agent) }
    let!(:other_deal) do
      other_pipeline = AgencyCrm::Pipeline.create!(account: other_account, name: 'Foreign pipeline')
      other_stage = other_pipeline.stages.create!(account: other_account, name: 'nuevo', position: 0, win_probability: 10)
      AgencyCrm::Deal.create!(account: other_account, pipeline: other_pipeline, stage: other_stage,
                              contact: create(:contact, account: other_account), title: 'Foreign deal')
    end
    let!(:other_task) do
      AgencyCrm::Task.create!(account: other_account, deal: other_deal, assignee: other_agent, title: 'Foreign task')
    end

    it 'returns 404 for update with a task from another account' do
      patch "/api/v1/accounts/#{account.id}/crm/tasks/#{other_task.id}",
            params: { task: { title: 'Hijacked' } }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:not_found)
      expect(other_task.reload.title).to eq('Foreign task')
    end

    it 'does not link a deal from another account on create' do
      post "/api/v1/accounts/#{account.id}/crm/tasks",
           params: { task: { title: 'Follow up', agency_deal_id: other_deal.id } }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(AgencyCrm::Task.order(:id).last.agency_deal_id).to be_nil
    end
  end
end
