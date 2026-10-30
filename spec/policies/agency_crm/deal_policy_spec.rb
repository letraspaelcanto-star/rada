# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgencyCrm::DealPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { AgencyCrm::Pipeline.create!(account: account, name: 'Ventas OB') }
  let(:stage) { pipeline.stages.create!(account: account, name: 'nuevo', position: 0, win_probability: 10) }
  let(:contact) { create(:contact, account: account) }
  let(:deal) do
    AgencyCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, contact: contact, title: 'Silla de ruedas')
  end

  let(:admin_context) { { user: admin, account: account, account_user: account.account_users.find_by(user_id: admin.id) } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.find_by(user_id: agent.id) } }

  permissions :index? do
    it { expect(policy).to permit(admin_context, AgencyCrm::Deal) }
    it { expect(policy).not_to permit(agent_context, AgencyCrm::Deal) }

    context 'when the agent belongs to any board (viewer alcanza)' do
      before { pipeline.board_memberships.create!(account: account, user: agent, role: :viewer) }

      it { expect(policy).to permit(agent_context, AgencyCrm::Deal) }
    end
  end

  permissions :create?, :update? do
    it { expect(policy).to permit(admin_context, deal) }

    context 'when the agent is an editor of the board' do
      before { pipeline.board_memberships.create!(account: account, user: agent, role: :editor) }

      it { expect(policy).to permit(agent_context, deal) }
    end

    context 'when the agent is only a viewer' do
      before { pipeline.board_memberships.create!(account: account, user: agent, role: :viewer) }

      it { expect(policy).not_to permit(agent_context, deal) }
    end

    context 'when the agent has no membership' do
      it { expect(policy).not_to permit(agent_context, deal) }
    end
  end

  describe 'Scope' do
    let!(:other_pipeline) { AgencyCrm::Pipeline.create!(account: account, name: 'Otro board') }
    let!(:other_stage) { other_pipeline.stages.create!(account: account, name: 'nuevo', position: 0, win_probability: 10) }
    let!(:other_deal) do
      AgencyCrm::Deal.create!(account: account, pipeline: other_pipeline, stage: other_stage,
                              contact: contact, title: 'Deal de otro board')
    end

    it 'devuelve todos los deals de la cuenta a un admin' do
      resolved = described_class::Scope.new(admin_context, AgencyCrm::Deal.where(account: account)).resolve

      expect(resolved).to include(deal, other_deal)
    end

    it 'devuelve solo los deals de los boards con membresía a un agente' do
      pipeline.board_memberships.create!(account: account, user: agent, role: :viewer)

      resolved = described_class::Scope.new(agent_context, AgencyCrm::Deal.where(account: account)).resolve

      expect(resolved).to include(deal).and exclude(other_deal)
    end
  end
end
