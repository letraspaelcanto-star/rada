# frozen_string_literal: true

# Timeline de un deal — contrato PLAN-DE-PROYECTO.md §5.
class Api::V1::Accounts::Crm::DealActivitiesController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(AgencyCrm::DealActivity) }
  before_action :fetch_deal

  RESULTS_PER_PAGE = 50

  def index
    @activities = @deal.activities.includes(:deal).order(created_at: :desc).page(params[:page]).per(RESULTS_PER_PAGE)
  end

  def create
    @activity = @deal.activities.create!(activity_params.merge(account: Current.account, actor_id: activity_actor_id))
    render 'api/v1/accounts/crm/deal_activities/show'
  end

  private

  def fetch_deal
    @deal = Current.account.agency_crm_deals.kept.find(params[:deal_id])
  end

  # actor_type user (o ausente) → el usuario autenticado; system/ai/automation actúan solos.
  def activity_actor_id
    actor_type = activity_params[:actor_type]
    return nil if actor_type.present? && actor_type != 'user'

    Current.user&.id
  end

  def activity_params
    params.require(:activity).permit(:kind, :body, :actor_type, metadata: {})
  end
end
