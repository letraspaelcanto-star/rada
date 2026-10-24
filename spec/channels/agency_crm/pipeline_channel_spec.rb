# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgencyCrm::PipelineChannel do
  let!(:account) { create(:account) }
  let!(:other_account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  let!(:pipeline) do
    AgencyCrm::Pipeline.create!(account: account, name: 'Ventas OB').tap do |p|
      p.stages.create!(account: account, name: 'nuevo', position: 0,
                       win_probability: 10, is_won: false, is_lost: false)
    end
  end

  let!(:foreign_pipeline) do
    AgencyCrm::Pipeline.create!(account: other_account, name: 'Pipeline ajeno').tap do |p|
      p.stages.create!(account: other_account, name: 'nuevo', position: 0,
                       win_probability: 10, is_won: false, is_lost: false)
    end
  end

  before do
    stub_connection
  end

  it 'subscribes an agent to the pipeline stream of its account' do
    subscribe(user_id: agent.id, pubsub_token: agent.pubsub_token,
              account_id: account.id, pipeline_id: pipeline.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for("pipeline:#{account.id}:#{pipeline.id}")
  end

  it 'rejects subscription to a pipeline of another account (aislamiento multi-cliente)' do
    subscribe(user_id: agent.id, pubsub_token: agent.pubsub_token,
              account_id: account.id, pipeline_id: foreign_pipeline.id)

    expect(subscription).to be_rejected
  end

  it 'rejects subscription with wrong pubsub_token' do
    subscribe(user_id: agent.id, pubsub_token: 'token-invalido',
              account_id: account.id, pipeline_id: pipeline.id)

    expect(subscription).to be_rejected
  end

  it 'rejects subscription when user does not belong to the account' do
    outsider = create(:user, account: other_account)

    subscribe(user_id: outsider.id, pubsub_token: outsider.pubsub_token,
              account_id: account.id, pipeline_id: pipeline.id)

    expect(subscription).to be_rejected
  end

  it 'rejects subscription to a non-existent pipeline' do
    subscribe(user_id: agent.id, pubsub_token: agent.pubsub_token,
              account_id: account.id, pipeline_id: 0)

    expect(subscription).to be_rejected
  end
end
