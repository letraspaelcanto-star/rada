# frozen_string_literal: true

require File.expand_path('../agency_crm_spec_helper', __dir__)
require File.expand_path('../../../../spec/rails_helper', __dir__)

RSpec.describe AgencyCrm::Pipeline do
  let(:account) { create(:account) }

  it 'es válido con nombre y account' do
    expect(described_class.new(account: account, name: 'Ventas OB')).to be_valid
  end

  it 'exige account (aislamiento por cliente — invariante §4)' do
    expect(described_class.new(name: 'Sin cuenta')).not_to be_valid
  end

  it 'exige nombre' do
    expect(described_class.new(account: account)).not_to be_valid
  end

  it 'ordena las etapas por position' do
    pipeline = create_agency_pipeline(account)
    segundo = create_agency_stage(pipeline, name: 'Contactado', position: 2)
    primero = create_agency_stage(pipeline, name: 'Nuevo', position: 1)
    expect(pipeline.stages.reload).to eq([primero, segundo])
  end

  it 'no filtra datos entre cuentas (scoping por account_id)' do
    otra_cuenta = create(:account)
    pipeline_a = create_agency_pipeline(account)
    create_agency_pipeline(otra_cuenta)

    # Ninguna query de la cuenta A devuelve pipelines de la cuenta B
    expect(described_class.where(account_id: account.id)).to eq([pipeline_a])
    expect(described_class.where(account_id: otra_cuenta.id)).not_to include(pipeline_a)
  end
end
