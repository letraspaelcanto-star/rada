# frozen_string_literal: true

# Canal en tiempo real del kanban CRM (PLAN-DE-PROYECTO.md §5).
#
# Stream: pipeline:<account_id>:<pipeline_id>
# Eventos: deal.created, deal.updated (mover tarjeta = deal.updated con stage_id nuevo)
#
# Autorización: mismo esquema que RoomChannel — pubsub_token del agente,
# membresía a la cuenta y pipeline que pertenece a esa cuenta. Nada de
# cross-account: si el pipeline no es de la cuenta, se rechaza la suscripción.
class AgencyCrm::PipelineChannel < ApplicationCable::Channel
  def subscribed
    return reject if current_user.blank? || current_account.blank? || current_pipeline.blank?
    return reject unless board_access?

    stream_from stream_name
  end

  private

  # Brief Sprint 3.5 ítem 5: admin de la cuenta o miembro del board (viewer/editor).
  def board_access?
    account_user = current_account.account_users.find_by(user_id: current_user.id)
    return true if account_user&.administrator?

    current_pipeline.board_memberships.exists?(user_id: current_user.id)
  end

  def stream_name
    "pipeline:#{current_account.id}:#{current_pipeline.id}"
  end

  def current_user
    @current_user ||= User.find_by(pubsub_token: params[:pubsub_token], id: params[:user_id])
  end

  def current_account
    @current_account ||= current_user&.accounts&.find_by(id: params[:account_id])
  end

  def current_pipeline
    @current_pipeline ||= AgencyCrm::Pipeline.find_by(id: params[:pipeline_id], account_id: params[:account_id])
  end
end
