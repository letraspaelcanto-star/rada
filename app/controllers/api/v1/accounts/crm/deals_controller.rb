# frozen_string_literal: true

# Deals (tarjetas del kanban) del CRM de agencia — contrato PLAN-DE-PROYECTO.md §5.
class Api::V1::Accounts::Crm::DealsController < Api::V1::Accounts::BaseController
  include Api::V1::Accounts::Crm::Authorizable

  include Sift
  sort_on :updated_at, type: :string

  RESULTS_PER_PAGE = 30

  # Modelo explícito: el controller está bajo namespace crm/ y classify sobre
  # "deals" resolvería ::Deal (constante inexistente).
  before_action -> { check_authorization(AgencyCrm::Deal) }, only: [:index]
  before_action :fetch_deal, only: [:update]

  # GET /crm/deals?stage_id=&status=&q=&page=
  def index
    @deals_count = filtered_deals.count
    @deals = filtered_deals.order(updated_at: :desc).page(params[:page]).per(RESULTS_PER_PAGE)
  end

  def create
    @deal = Current.account.agency_crm_deals.new(deal_params.except(:contact_id, :conversation_id, :company_id, :assignee_id))
    assign_linked_records
    authorize_crm(@deal)
    return if performed?

    @deal.save!
    render 'api/v1/accounts/crm/deals/show'
  end

  # Doble autorización: primero contra el board ORIGINAL (hay que poder escribir
  # el deal que se toca) y, tras aplicar params, contra el board NUEVO — mover un
  # deal de A a B exige ser editor (o admin) de los DOS (review rada#14).
  def update
    authorize_crm(@deal)
    return if performed?

    @deal.assign_attributes(deal_params.except(:contact_id, :conversation_id, :company_id, :assignee_id))
    assign_linked_records
    authorize_crm(@deal)
    return if performed?

    @deal.save!
    render 'api/v1/accounts/crm/deals/show'
  end

  private

  def fetch_deal
    @deal = Current.account.agency_crm_deals.kept.find(params[:id])
  end

  def filter_by_search(deals)
    search = "%#{params[:q].strip}%"
    deals.left_joins(:contact).where(
      'agency_deals.title ILIKE :search OR agency_deals.lost_reason ILIKE :search OR contacts.name ILIKE :search',
      search: search
    )
  end

  # Los registros linkeados se resuelven SIEMPRE dentro de la cuenta (aislamiento
  # por cliente). Contacto ajeno → 404 (find, contrato de la API); conversation,
  # company y assignee ajenos → 422 con error (brief ítem 3), no ignorarlos.
  def assign_linked_records
    assign_contact if deal_params[:contact_id].present?
    assign_conversation if deal_params[:conversation_id].present?
    assign_company if deal_params[:company_id].present?
    assign_assignee if deal_params[:assignee_id].present?
  end

  def assign_contact
    @deal.contact = Current.account.contacts.find(deal_params[:contact_id])
  end

  def assign_conversation
    @deal.conversation = Current.account.conversations.find(deal_params[:conversation_id])
  rescue ActiveRecord::RecordNotFound
    raise_record_invalid(:conversation_id)
  end

  def assign_company
    @deal.company = Current.account.companies.find(deal_params[:company_id])
  rescue ActiveRecord::RecordNotFound
    raise_record_invalid(:company_id)
  end

  def assign_assignee
    @deal.assignee = Current.account.users.find(deal_params[:assignee_id])
  rescue ActiveRecord::RecordNotFound
    raise_record_invalid(:assignee_id)
  end

  def raise_record_invalid(attribute)
    @deal.errors.add(attribute, 'belongs to another account or does not exist')
    raise ActiveRecord::RecordInvalid, @deal
  end

  def filtered_deals
    deals = policy_scope(Current.account.agency_crm_deals.kept).includes(:stage, :contact, :assignee)
    deals = deals.where(agency_pipeline_stage_id: params[:stage_id]) if params[:stage_id].present?
    deals = deals.where(status: params[:status]) if params[:status].present?
    deals = filter_by_search(deals) if params[:q].present?
    deals
  end

  def deal_params
    params.require(:deal).permit(:title, :agency_pipeline_id, :agency_pipeline_stage_id, :contact_id, :conversation_id,
                                 :company_id, :assignee_id, :value_cents, :currency, :priority, :status,
                                 :expected_close_on, :closed_on, :lost_reason, custom_attributes: {})
  end
end
