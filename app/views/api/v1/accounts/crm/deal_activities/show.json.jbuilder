# frozen_string_literal: true

json.payload do
  json.partial! 'api/v1/models/crm_deal_activity', formats: [:json], activity: @activity
end
