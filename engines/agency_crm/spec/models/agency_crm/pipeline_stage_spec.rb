# frozen_string_literal: true

require File.expand_path('../../agency_crm_spec_helper', __dir__)
require File.expand_path('../../../../../spec/rails_helper', __dir__)

RSpec.describe AgencyCrm::PipelineStage do
  let(:account) { create(:account) }
  let(:pipeline) { create_agency_pipeline(account) }

  it 'exige nombre' do
    expect(described_class.new(account: account, pipeline: pipeline)).not_to be_valid
  end

  it 'win_probability entre 0 y 100' do
    stage = described_class.new(account: account, pipeline: pipeline, name: 'X')
    stage.win_probability = 101
    expect(stage).not_to be_valid
    stage.win_probability = -1
    expect(stage).not_to be_valid
    stage.win_probability = 80
    expect(stage).to be_valid
  end

  describe 'invariante: etapa ganada/perdida unica por pipeline' do
    it 'permite una sola is_won por pipeline' do
      create_agency_stage(pipeline, name: 'Ganado', is_won: true)
      duplicada = described_class.new(account: account, pipeline: pipeline, name: 'Ganado 2', is_won: true)
      expect(duplicada).not_to be_valid
    end

    it 'permite una sola is_lost por pipeline' do
      create_agency_stage(pipeline, name: 'Perdido', is_lost: true)
      duplicada = described_class.new(account: account, pipeline: pipeline, name: 'Perdido 2', is_lost: true)
      expect(duplicada).not_to be_valid
    end

    it 'permite is_won e is_lost distintas en el mismo pipeline' do
      create_agency_stage(pipeline, name: 'Ganado', is_won: true)
      perdido = described_class.new(account: account, pipeline: pipeline, name: 'Perdido', is_lost: true)
      expect(perdido).to be_valid
    end

    it 'otro pipeline puede tener su propia etapa ganada' do
      create_agency_stage(pipeline, name: 'Ganado', is_won: true)
      otro = create_agency_pipeline(account)
      expect(described_class.new(account: account, pipeline: otro, name: 'Ganado', is_won: true)).to be_valid
    end
  end

  describe 'aislamiento entre cuentas' do
    let(:other_account) { create(:account) }
    let!(:own_stage) { create_agency_stage(pipeline, name: 'Contactado') }
    let!(:foreign_stage) { create_agency_stage(create_agency_pipeline(other_account), name: 'Nuevo (ajeno)') }

    it 'where(account:) no devuelve etapas de otra cuenta' do
      scoped = described_class.where(account: account)
      expect(scoped).to include(own_stage)
      expect(scoped).not_to include(foreign_stage)
    end

    it 'pipeline.stages no expone etapas de un pipeline de otra cuenta' do
      expect(pipeline.stages).to include(own_stage)
      expect(pipeline.stages).not_to include(foreign_stage)
    end
  end
end
