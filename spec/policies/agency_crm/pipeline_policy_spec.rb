# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgencyCrm::PipelinePolicy, type: :policy do
  subject(:policy) { described_class }

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { AgencyCrm::Pipeline.create!(account: account, name: 'Ventas OB') }

  let(:admin_context) { { user: admin, account: account, account_user: account.account_users.find_by(user_id: admin.id) } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.find_by(user_id: agent.id) } }

  permissions :show? do
    it 'permite al admin de la cuenta sin membresía' do
      expect(policy).to permit(admin_context, pipeline)
    end

    context 'when the agent has a viewer membership' do
      before { pipeline.board_memberships.create!(account: account, user: agent, role: :viewer) }

      it { expect(policy).to permit(agent_context, pipeline) }
    end

    context 'when the agent has no membership' do
      it 'raises RecordNotFound (la respuesta es 404, no 403)' do
        expect { policy.new(agent_context, pipeline).show? }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  permissions :create?, :reorder_stages? do
    it { expect(policy).to permit(admin_context, pipeline) }

    context 'when the agent has an editor membership' do
      before { pipeline.board_memberships.create!(account: account, user: agent, role: :editor) }

      it 'sigue sin permitir: crear boards y reordenar etapas es de admin' do
        expect(policy).not_to permit(agent_context, pipeline)
      end
    end
  end

  describe 'Scope' do
    let!(:other_pipeline) { AgencyCrm::Pipeline.create!(account: account, name: 'Otro board') }

    it 'devuelve todos los boards de la cuenta a un admin' do
      resolved = described_class::Scope.new(admin_context, AgencyCrm::Pipeline.where(account: account)).resolve

      expect(resolved).to include(pipeline, other_pipeline)
    end

    it 'devuelve solo los boards con membresía a un agente' do
      pipeline.board_memberships.create!(account: account, user: agent, role: :viewer)

      resolved = described_class::Scope.new(agent_context, AgencyCrm::Pipeline.where(account: account)).resolve

      expect(resolved).to include(pipeline).and exclude(other_pipeline)
    end
  end
end
