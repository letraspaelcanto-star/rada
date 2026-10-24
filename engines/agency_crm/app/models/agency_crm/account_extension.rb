# frozen_string_literal: true

# Asociaciones de Account hacia el CRM de agencia.
#
# Viven en el engine (no editadas en app/models/account.rb) para no inflar la
# clase upstream — ya roza el límite de Metrics/ClassLength.
module AgencyCrm::AccountExtension
  extend ActiveSupport::Concern

  included do
    # aislamiento por cuenta del modelo agencia (PLAN-DE-PROYECTO.md §4-5)
    has_many :agency_crm_pipelines, dependent: :destroy_async, class_name: 'AgencyCrm::Pipeline'
    has_many :agency_crm_deals, dependent: :destroy_async, class_name: 'AgencyCrm::Deal'
    has_many :agency_crm_tasks, dependent: :destroy_async, class_name: 'AgencyCrm::Task'
  end
end
