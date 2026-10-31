# frozen_string_literal: true

require File.expand_path('../../agency_crm_spec_helper', __dir__)
require File.expand_path('../../../../../spec/rails_helper', __dir__)

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

  describe 'la etapa tiene que ser del mismo pipeline (ADR 0003)' do
    it 'rechaza una etapa de otro pipeline, aun de la misma cuenta' do
      otro_pipeline = create_agency_pipeline(account)
      stage_de_otro = create_agency_stage(otro_pipeline, name: 'Nuevo')

      expect(new_deal(stage: stage_de_otro)).not_to be_valid
    end
  end

  describe 'un deal abierto por contacto y pipeline (ADR 0003)' do
    let(:otro_contacto) { create(:contact, account: account) }

    it 'rechaza un segundo abierto para el mismo contacto y pipeline, y nombra el existente' do
      existente = new_deal
      existente.save!
      duplicado = new_deal

      expect(duplicado).not_to be_valid
      expect(duplicado.errors.full_messages.join(' ')).to include("deal ##{existente.id}")
    end

    it 'permite dos abiertos del mismo contacto en pipelines distintos' do
      otro_pipeline = create_agency_pipeline(account)
      new_deal.save!

      otro = new_deal(pipeline: otro_pipeline, stage: create_agency_stage(otro_pipeline, name: 'Nuevo'))
      expect(otro).to be_valid
    end

    it 'permite dos abiertos del mismo pipeline con contactos distintos' do
      new_deal.save!

      expect(new_deal(contact: otro_contacto)).to be_valid
    end

    it 'los ganados o perdidos no cuentan' do
      ganado = new_deal
      ganado.save!
      ganado.won!

      expect(new_deal).to be_valid
    end

    it 'un descartado no bloquea' do
      descartado = new_deal
      descartado.save!
      descartado.discard

      expect(new_deal).to be_valid
    end

    it 'rechaza reabrir uno ganado si ya hay otro abierto para el mismo contacto y pipeline' do
      abierto = new_deal
      abierto.save!
      ganado = new_deal(stage: create_agency_stage(pipeline, name: 'Ganado', is_won: true))
      ganado.save!

      expect(ganado.update(stage: stage)).to be(false)
      expect(ganado.errors.full_messages.join(' ')).to include("deal ##{abierto.id}")
      expect(ganado.reload.status).to eq('won')
    end

    it 'rechaza mover el deal a un pipeline donde el contacto ya tiene uno abierto' do
      otro_pipeline = create_agency_pipeline(account)
      stage_alla = create_agency_stage(otro_pipeline, name: 'Nuevo')
      abierto_alla = new_deal(pipeline: otro_pipeline, stage: stage_alla)
      abierto_alla.save!
      deal = new_deal
      deal.save!

      deal.pipeline = otro_pipeline
      deal.stage = stage_alla

      expect(deal).not_to be_valid
      expect(deal.errors.full_messages.join(' ')).to include("deal ##{abierto_alla.id}")
    end

    it 'rechaza cambiar a mano el contacto por uno que ya tiene un abierto en el pipeline' do
      abierto_del_otro = new_deal(contact: otro_contacto)
      abierto_del_otro.save!
      deal = new_deal
      deal.save!

      deal.contact = otro_contacto

      expect(deal).not_to be_valid
      expect(deal.errors.full_messages.join(' ')).to include("deal ##{abierto_del_otro.id}")
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

  describe 'ganar y perder desde la etapa' do
    let(:ganado) { create_agency_stage(pipeline, name: 'ganado', is_won: true) }
    let(:perdido) { create_agency_stage(pipeline, name: 'perdido', is_lost: true) }

    it 'mover a la etapa ganada marca won y setea closed_on' do
      deal = new_deal
      deal.save!
      deal.update!(stage: ganado)

      expect(deal.reload).to have_attributes(status: 'won', closed_on: Time.zone.today)
    end

    it 'mover a la etapa perdida marca lost y setea closed_on' do
      deal = new_deal
      deal.save!
      deal.update!(stage: perdido)

      expect(deal.reload).to have_attributes(status: 'lost', closed_on: Time.zone.today)
    end

    it 'salir de una etapa terminal reabre el deal y limpia closed_on' do
      deal = new_deal(stage: ganado)
      deal.save!
      deal.update!(stage: stage)

      expect(deal.reload).to have_attributes(status: 'open', closed_on: nil)
    end

    it 'crear un deal directo en la etapa ganada lo crea won' do
      deal = new_deal(stage: ganado)
      deal.save!

      expect(deal.reload).to have_attributes(status: 'won', closed_on: Time.zone.today)
    end

    it 'respeta un closed_on ya cargado' do
      deal = new_deal(closed_on: Date.new(2026, 10, 1))
      deal.save!
      deal.update!(stage: ganado)

      expect(deal.reload.closed_on).to eq(Date.new(2026, 10, 1))
    end

    it 'crear un deal con status explicito en una etapa abierta lo respeta' do
      deal = new_deal(status: :won)
      deal.save!

      expect(deal.reload.status).to eq('won')
    end

    it 'mover entre etapas abiertas no toca el status' do
      deal = new_deal
      deal.save!
      deal.update!(stage: create_agency_stage(pipeline, name: 'cotizado'))

      expect(deal.reload).to have_attributes(status: 'open', closed_on: nil)
    end

    it 'mover a la etapa ganada despacha deal_won' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
      deal = new_deal
      deal.save!
      deal.update!(stage: ganado)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with('deal_won', kind_of(Time), hash_including(deal: deal))
    end
  end

  describe 'webhooks deal_* por el dispatcher' do
    let(:otra_stage) { create_agency_stage(pipeline, name: 'Cotizado') }

    before { allow(Rails.configuration.dispatcher).to receive(:dispatch) }

    it 'despacha deal_created al crear' do
      deal = new_deal
      deal.save!

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with('deal_created', kind_of(Time), account: account, deal: deal, changed_attributes: nil, performed_by: nil)
    end

    it 'despacha deal_stage_changed al cambiar de etapa' do
      deal = new_deal
      deal.save!
      deal.update!(stage: otra_stage)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with('deal_stage_changed', kind_of(Time), hash_including(deal: deal))
    end

    it 'despacha deal_won y deal_lost al cambiar el status' do
      ganado = new_deal
      ganado.save!
      ganado.won!
      perdido = new_deal(title: 'Silla de ruedas', contact: create(:contact, account: account))
      perdido.save!
      perdido.lost!

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with('deal_won', kind_of(Time), hash_including(deal: ganado))
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with('deal_lost', kind_of(Time), hash_including(deal: perdido))
    end

    it 'no despacha si la transaccion hace rollback' do
      ActiveRecord::Base.transaction(requires_new: true) do
        new_deal.save!
        raise ActiveRecord::Rollback
      end

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with('deal_created', any_args)
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
