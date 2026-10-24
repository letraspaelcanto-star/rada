# frozen_string_literal: true

json.payload do
  json.partial! 'api/v1/models/crm_deal', formats: [:json], deal: @deal
end
