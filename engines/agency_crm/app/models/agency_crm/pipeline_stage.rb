# frozen_string_literal: true

# == Schema Information (contrato PLAN-DE-PROYECTO.md §4)
#
# Tabla: agency_pipeline_stages
#
# Invariante: a lo sumo una etapa is_won y una is_lost por pipeline.
#
module AgencyCrm
  class PipelineStage < ApplicationRecord
    self.table_name = 'agency_pipeline_stages'

    belongs_to :account
    belongs_to :pipeline, class_name: 'AgencyCrm::Pipeline', foreign_key: 'agency_pipeline_id', inverse_of: :stages

    has_many :deals, class_name: 'AgencyCrm::Deal', foreign_key: 'agency_pipeline_stage_id', inverse_of: :stage,
             dependent: :restrict_with_error

    validates :name, presence: true
    validates :win_probability, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    validate :uniqueness_of_terminal_stage

    scope :terminal, -> { where(is_won: true).or(where(is_lost: true)) }

    private

    def uniqueness_of_terminal_stage
      return unless is_won || is_lost

      flag = is_won ? :is_won : :is_lost
      scope = pipeline&.stages&.where(flag => true)&.where.not(id: id)
      errors.add(flag, :taken) if scope&.exists?
    end
  end
end
