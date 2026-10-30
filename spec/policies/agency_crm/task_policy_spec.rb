# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgencyCrm::TaskPolicy, type: :policy do
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
  let(:task) { AgencyCrm::Task.new(account: account, deal: deal, title: 'Llamar mañana') }
  let(:loose_task) { AgencyCrm::Task.new(account: account, title: 'Tarea suelta') }

  let(:admin_context) { { user: admin, account: account, account_user: account.account_users.find_by(user_id: admin.id) } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.find_by(user_id: agent.id) } }

  permissions :create?, :update? do
    it { expect(policy).to permit(admin_context, task) }

    context 'when the agent is an editor of the deal board' do
      before { pipeline.board_memberships.create!(account: account, user: agent, role: :editor) }

      it { expect(policy).to permit(agent_context, task) }
    end

    context 'when the agent is only a viewer of the deal board' do
      before { pipeline.board_memberships.create!(account: account, user: agent, role: :viewer) }

      it { expect(policy).not_to permit(agent_context, task) }
    end

    context 'when the agent has no membership' do
      it { expect(policy).not_to permit(agent_context, task) }
    end

    context 'when the task is not linked to a deal' do
      it { expect(policy).to permit(admin_context, loose_task) }

      it 'la crea cualquier miembro de algún board' do
        pipeline.board_memberships.create!(account: account, user: agent, role: :viewer)

        expect(policy).to permit(agent_context, loose_task)
      end

      it 'la rechaza sin ninguna membresía' do
        expect(policy).not_to permit(agent_context, loose_task)
      end
    end
  end
end
