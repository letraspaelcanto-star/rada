# frozen_string_literal: true

require File.expand_path('../../agency_crm_spec_helper', __dir__)
require File.expand_path('../../../../../spec/rails_helper', __dir__)

RSpec.describe AgencyCrm::BoardMembership do
  let(:account) { create(:account) }
  let(:pipeline) { create_agency_pipeline(account) }
  let(:user) { create(:user) }

  before { create(:account_user, account: account, user: user) }

  it 'es valido con user que pertenece a la cuenta via account_users' do
    expect(described_class.new(account: account, pipeline: pipeline, user: user)).to be_valid
  end

  it 'rechaza un user que NO pertenece a la cuenta (invariante §4)' do
    externo = create(:user)
    expect(described_class.new(account: account, pipeline: pipeline, user: externo)).not_to be_valid
  end

  it 'un usuario no puede tener dos membresias en el mismo pipeline' do
    described_class.create!(account: account, pipeline: pipeline, user: user)
    duplicada = described_class.new(account: account, pipeline: pipeline, user: user)
    expect(duplicada).not_to be_valid
  end

  it 'rol viewer por defecto, editor disponible' do
    membership = described_class.create!(account: account, pipeline: pipeline, user: user)
    expect(membership.viewer?).to be true
    membership.editor!
    expect(membership.reload.editor?).to be true
  end

  describe 'aislamiento entre cuentas' do
    let(:other_account) { create(:account) }
    let(:other_user) { create(:user, account: other_account) }
    let!(:own_membership) { described_class.create!(account: account, pipeline: pipeline, user: user) }
    let!(:foreign_membership) do
      foreign_pipeline = create_agency_pipeline(other_account)
      described_class.create!(account: other_account, pipeline: foreign_pipeline, user: other_user)
    end

    it 'where(account:) no devuelve membresias de otra cuenta' do
      scoped = described_class.where(account: account)
      expect(scoped).to include(own_membership)
      expect(scoped).not_to include(foreign_membership)
    end

    it 'pipeline.board_memberships no expone membresias de un pipeline de otra cuenta' do
      expect(pipeline.board_memberships).to include(own_membership)
      expect(pipeline.board_memberships).not_to include(foreign_membership)
    end
  end
end
