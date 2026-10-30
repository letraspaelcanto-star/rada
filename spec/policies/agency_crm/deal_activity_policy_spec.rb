# frozen_string_literal: true

require 'rails_helper'

# El record de esta policy es el deal padre (el controller autoriza con
# `policy_class: AgencyCrm::DealActivityPolicy`): el board que manda es el del deal.
RSpec.describe AgencyCrm::DealActivityPolicy, type: :policy do
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
    it { expect(policy).to permit(admin_context, deal) }

    context 'when the agent has a viewer membership (leer alcanza)' do
      before { pipeline.board_memberships.create!(account: account, user: agent, role: :viewer) }

      it { expect(policy).to permit(agent_context, deal) }
    end

    context 'when the agent has no membership' do
      it { expect(policy).not_to permit(agent_context, deal) }
    end
  end

  permissions :create? do
    context 'when the agent is an editor of the deal board' do
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
end
