# frozen_string_literal: true

# Autorización de los endpoints CRM (brief Sprint 3.5 ítem 5): el handler
# global (RequestExceptionHandler) responde 401 ante Pundit::NotAuthorizedError,
# estado reservado para "no autenticado". El contrato del CRM exige 403 para
# "autenticado sin permiso", así que las denegaciones de estas policies se
# renderizan acá como forbidden.
module Api::V1::Accounts::Crm::Authorizable
  extend ActiveSupport::Concern

  CRM_FORBIDDEN_MESSAGE = 'You are not authorized to do this action'

  private

  def check_authorization(model = nil, policy_class: nil)
    authorize(model, policy_class: policy_class)
  rescue Pundit::NotAuthorizedError
    render json: { error: CRM_FORBIDDEN_MESSAGE }, status: :forbidden
  end

  # Autoriza una instancia dentro de la acción (create/update). Si deniega,
  # ya renderizó 403: cortá la acción con `return if performed?`.
  def authorize_crm(record)
    authorize(record)
  rescue Pundit::NotAuthorizedError
    render json: { error: CRM_FORBIDDEN_MESSAGE }, status: :forbidden
  end
end
