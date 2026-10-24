# frozen_string_literal: true

# Recorrido real de venta de Ortopedia Belgrano — PLAN-DE-PROYECTO.md §5.1.
# nombre, probabilidad, flags terminales (ganado 100 / perdido 0; intermedias a
# calibrar con datos reales).
OB_PIPELINE_STAGES = [
  { name: 'nuevo',        win_probability: 10,  is_won: false, is_lost: false },
  { name: 'contactado',   win_probability: 30,  is_won: false, is_lost: false },
  { name: 'cotizado',     win_probability: 60,  is_won: false, is_lost: false },
  { name: 'pensando',     win_probability: 50,  is_won: false, is_lost: false },
  { name: 'visito_local', win_probability: 75,  is_won: false, is_lost: false },
  { name: 'ganado',       win_probability: 100, is_won: true,  is_lost: false },
  { name: 'perdido',      win_probability: 0,   is_won: false, is_lost: true }
].freeze

namespace :agency_crm do
  desc 'Seed idempotente del pipeline OB (ventas) con sus etapas'
  task seed_ob_pipeline: :environment do
    account_id = ENV.fetch('ACCOUNT_ID', nil)
    account = account_id.present? ? Account.find(account_id) : Account.first
    raise 'No hay accounts en el sistema. Creá una primero (o pasá ACCOUNT_ID).' if account.nil?

    pipeline = AgencyCrm::Pipeline.find_or_initialize_by(account: account, name: 'Ventas OB')

    if pipeline.persisted?
      puts "Pipeline 'Ventas OB' ya existe (account #{account.id} #{account.name}) — etapas: #{pipeline.stages.count}. Nada que hacer."
      next
    end

    pipeline.description = 'Recorrido de venta de Ortopedia Belgrano — ficha de lead a cliente'
    pipeline.save!

    OB_PIPELINE_STAGES.each_with_index do |attrs, position|
      pipeline.stages.create!(attrs.merge(account: account, position: position, automation_config: {}))
    end

    puts "Pipeline 'Ventas OB' creado en account #{account.id} (#{account.name}) con #{OB_PIPELINE_STAGES.size} etapas."
  end
end
