# frozen_string_literal: true

require 'rake'
require 'rails_helper'

RSpec.describe Rake::Task do
  describe 'agency_crm:seed_ob_pipeline' do
    subject(:task) { described_class['agency_crm:seed_ob_pipeline'] }

    let(:account) { create(:account) }
    let!(:agent_one) { create(:user, account: account, role: :agent) }
    let!(:agent_two) { create(:user, account: account, role: :agent) }
    let!(:admin) { create(:user, account: account, role: :administrator) }

    before { task.reenable }

    around { |example| with_modified_env(ACCOUNT_ID: account.id.to_s, &example) }

    it 'creates the pipeline, its stages and editor memberships for every agent' do
      expect { task.invoke }.to change(AgencyCrm::Pipeline, :count).by(1)
                                                                   .and change(AgencyCrm::PipelineStage, :count).by(7)
                                                                                                                .and change(
                                                                                                                  AgencyCrm::BoardMembership, :count
                                                                                                                ).by(2)

      pipeline = account.agency_crm_pipelines.find_by!(name: 'Ventas OB')
      editor_ids = pipeline.board_memberships.editor.map(&:user_id)
      expect(editor_ids).to contain_exactly(agent_one.id, agent_two.id)
      expect(editor_ids).not_to include(admin.id)
    end

    it 'is idempotent: a second run duplicates nothing' do
      task.invoke

      task.reenable
      expect { task.invoke }.not_to change(AgencyCrm::Pipeline, :count)
      task.reenable
      expect { task.invoke }.not_to change(AgencyCrm::PipelineStage, :count)
      task.reenable
      expect { task.invoke }.not_to change(AgencyCrm::BoardMembership, :count)
    end

    it 'backfills memberships on an existing pipeline (creado antes del ítem 5)' do
      pipeline = AgencyCrm::Pipeline.create!(account: account, name: 'Ventas OB')

      expect { task.invoke }.to change(AgencyCrm::BoardMembership, :count).by(2)
      expect(pipeline.board_memberships.reload.editor.count).to eq(2)
    end

    it 'adds a membership only for agents who joined later' do
      task.invoke
      late_agent = create(:user, account: account, role: :agent)
      task.reenable

      expect { task.invoke }.to change(AgencyCrm::BoardMembership, :count).by(1)
      expect(AgencyCrm::BoardMembership.find_by!(user: late_agent)).to be_editor
    end
  end
end
