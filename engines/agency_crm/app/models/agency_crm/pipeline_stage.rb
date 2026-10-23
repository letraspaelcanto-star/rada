# frozen_string_literal: true

# == Schema Information (contrato PLAN-DE-PROYECTO.md §4)
#
# Tabla: agency_pipeline_stages
#
# Invariante: a lo sumo una etapa is_won y una is_lost por pipeline.
#
class AgencyCrm::PipelineStage < ApplicationRecord
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
    flag = terminal_flag
    return if flag.blank? || pipeline.nil?

    errors.add(flag, :taken) if pipeline.stages.where(flag => true).where.not(id: id).exists?
  end

  def terminal_flag
    return :is_won if is_won
    return :is_lost if is_lost
  end
end
