# frozen_string_literal: true

json.meta do
  json.count @deals_count
  json.current_page params[:page] || 1
end

json.payload do
  json.array! @deals do |deal|
    json.partial! 'api/v1/models/crm_deal', formats: [:json], deal: deal
  end
end
