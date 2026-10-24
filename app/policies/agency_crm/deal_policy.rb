# frozen_string_literal: true

# Los agentes operan deals (crear, mover, ganar/perder) — el CRM es herramienta
# de trabajo diaria, no solo de administradores.
class AgencyCrm::DealPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def update?
    true
  end
end
