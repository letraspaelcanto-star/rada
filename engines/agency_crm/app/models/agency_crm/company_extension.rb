# frozen_string_literal: true

# Borrar una empresa no puede fallar por deals ligados (ADR 0002): el vínculo
# pasa a NULL y el histórico de ventas se conserva.
module AgencyCrm::CompanyExtension
  extend ActiveSupport::Concern

  included do
    has_many :agency_crm_deals, class_name: 'AgencyCrm::Deal', foreign_key: :company_id, dependent: :nullify
  end
end
