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
    deal_id = task_params[:agency_deal_id]
    @task.deal = Current.account.agency_crm_deals.find_by(id: deal_id) if deal_id.present?
    conversation_id = task_params[:conversation_id]
    @task.conversation = Current.account.conversations.find_by(id: conversation_id) if conversation_id.present?
    assignee_id = task_params[:assignee_id]
    @task.assignee = Current.account.users.find_by(id: assignee_id) if assignee_id.present?
  end

  def task_params
    params.require(:task).permit(:title, :agency_deal_id, :conversation_id, :assignee_id, :due_at, :completed_at)
  end
end
