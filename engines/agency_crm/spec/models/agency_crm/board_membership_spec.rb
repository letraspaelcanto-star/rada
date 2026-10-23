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
end
