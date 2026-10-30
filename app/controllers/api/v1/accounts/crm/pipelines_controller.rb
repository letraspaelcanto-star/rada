# frozen_string_literal: true

# Pipelines (boards) del CRM de agencia — contrato PLAN-DE-PROYECTO.md §5.
class Api::V1::Accounts::Crm::PipelinesController < Api::V1::Accounts::BaseController
  include Api::V1::Accounts::Crm::Authorizable

  before_action -> { check_authorization(AgencyCrm::Pipeline) }, only: [:index, :create]
  before_action :fetch_pipeline, only: [:show, :reorder_stages]
  before_action -> { authorize_crm(@pipeline) }, only: [:show, :reorder_stages]

  def index
    @pipelines = policy_scope(Current.account.agency_crm_pipelines).includes(:stages)
  end

  def show; end

  def create
    @pipeline = Current.account.agency_crm_pipelines.create!(pipeline_params)
    render 'api/v1/accounts/crm/pipelines/show'
  end

  def reorder_stages
    stage_ids = params[:stage_ids]
    if stage_ids.blank? || stage_ids.map(&:to_i).sort != @pipeline.stages.map(&:id).sort
      render json: { error: 'stage_ids must include every stage of the pipeline exactly once' }, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      stage_ids.each_with_index do |stage_id, position|
        @pipeline.stages.where(id: stage_id).update!(position: position)
      end
    end
    render 'api/v1/accounts/crm/pipelines/show'
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.agency_crm_pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :description)
  end
end
