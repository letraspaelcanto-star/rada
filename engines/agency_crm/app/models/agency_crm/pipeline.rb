# frozen_string_literal: true

# == Schema Information (contrato PLAN-DE-PROYECTO.md §4)
#
# Tabla: agency_pipelines
#
module AgencyCrm
  class Pipeline < ApplicationRecord
    self.table_name = 'agency_pipelines'

    belongs_to :account

    has_many :stages, -> { order(position: :asc) },
             class_name: 'AgencyCrm::PipelineStage', foreign_key: 'agency_pipeline_id',
             inverse_of: :pipeline, dependent: :destroy
    has_many :deals, class_name: 'AgencyCrm::Deal', foreign_key: 'agency_pipeline_id', inverse_of: :pipeline, dependent: :restrict_with_error
    has_many :board_memberships, class_name: 'AgencyCrm::BoardMembership', foreign_key: 'agency_pipeline_id',
             inverse_of: :pipeline, dependent: :destroy

    validates :name, presence: true
  end
end
