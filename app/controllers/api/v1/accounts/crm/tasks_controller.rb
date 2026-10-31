# frozen_string_literal: true

# Tareas del CRM de agencia — contrato PLAN-DE-PROYECTO.md §5.
class Api::V1::Accounts::Crm::TasksController < Api::V1::Accounts::BaseController
  include Api::V1::Accounts::Crm::Authorizable

  before_action :fetch_task, only: [:update]

  def create
    @task = Current.account.agency_crm_tasks.new(task_params.except(:agency_deal_id, :conversation_id, :assignee_id))
    assign_linked_records
    authorize_crm(@task)
    return if performed?

    @task.assignee ||= Current.user
    @task.save!
    render 'api/v1/accounts/crm/tasks/show'
  end

  # Igual que en deals#update: autorizar contra el deal ORIGINAL y, si el patch
  # la relinkea a otro deal, contra el deal NUEVO — editor de los DOS boards.
  def update
    authorize_crm(@task)
    return if performed?

    @task.assign_attributes(task_params.except(:agency_deal_id, :conversation_id, :assignee_id))
    assign_linked_records
    authorize_crm(@task)
    return if performed?

    @task.save!
    render 'api/v1/accounts/crm/tasks/show'
  end

  private

  def fetch_task
    @task = Current.account.agency_crm_tasks.find(params[:id])
  end

  def assign_linked_records
    assign_deal if task_params[:agency_deal_id].present?
    assign_conversation if task_params[:conversation_id].present?
    assign_assignee if task_params[:assignee_id].present?
  end

  def assign_deal
    @task.deal = Current.account.agency_crm_deals.find(task_params[:agency_deal_id])
  rescue ActiveRecord::RecordNotFound
    raise_record_invalid(:agency_deal_id)
  end

  def assign_conversation
    @task.conversation = Current.account.conversations.find_by(id: task_params[:conversation_id])
  end

  def assign_assignee
    @task.assignee = Current.account.users.find(task_params[:assignee_id])
  rescue ActiveRecord::RecordNotFound
    raise_record_invalid(:assignee_id)
  end

  def raise_record_invalid(attribute)
    @task.errors.add(attribute, 'belongs to another account or does not exist')
    raise ActiveRecord::RecordInvalid, @task
  end

  def task_params
    params.require(:task).permit(:title, :agency_deal_id, :conversation_id, :assignee_id, :due_at, :completed_at)
  end
end
