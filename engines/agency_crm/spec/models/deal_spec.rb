# frozen_string_literal: true

require File.expand_path('../agency_crm_spec_helper', __dir__)
require File.expand_path('../../../../spec/rails_helper', __dir__)

RSpec.describe AgencyCrm::Deal do
  let(:account) { create(:account) }
  let(:pipeline) { create_agency_pipeline(account) }
  let(:stage) { create_agency_stage(pipeline, name: 'Nuevo') }
  let(:contact) { create(:contact, account: account) }

  def new_deal(overrides = {})
    described_class.new({ account: account, pipeline: pipeline, stage: stage, contact: contact, title: 'Cama Centuris' }.merge(overrides))
  end

  it 'es valido con los campos del contrato' do
    expect(new_deal).to be_valid
  end

  it 'exige titulo' do
    expect(new_deal(title: nil)).not_to be_valid
  end

  it 'rechaza valor negativo' do
    expect(new_deal(value_cents: -100)).not_to be_valid
  end

  describe 'aislamiento por account (invariante critica)' do
    it 'rechaza una stage de otra cuenta' do
      otra_cuenta = create(:account)
      otra_stage = create_agency_stage(create_agency_pipeline(otra_cuenta), name: 'Nuevo')
      expect(new_deal(stage: otra_stage)).not_to be_valid
    end

    it 'rechaza un pipeline de otra cuenta' do
      otra_cuenta = create(:account)
      otro_pipeline = create_agency_pipeline(otra_cuenta)
      expect(new_deal(pipeline: otro_pipeline)).not_to be_valid
    end
  end

  describe 'enums alineados con Conversation' do
    it 'priority usa los mismos valores que Conversation (low:0..urgent:3)' do
      expect(described_class.priorities).to eq('low' => 0, 'medium' => 1, 'high' => 2, 'urgent' => 3)
      expect(described_class.priorities).to eq(Conversation.priorities)
    end

    it 'status open/won/lost' do
      deal = new_deal
      expect(deal.status).to eq('open')
      deal.won!
      expect(deal.reload.status).to eq('won')
    end
  end

  describe 'soft-delete' do
    it 'discard marca discarded_at y lo saca del scope kept' do
      deal = new_deal
      deal.save!
      expect { deal.discard }.to change { deal.reload.discarded_at }.from(nil)
      expect(described_class.kept).not_to include(deal)
      expect(described_class.discarded).to include(deal)
    end
  end
end
