# frozen_string_literal: true

json.meta do
  json.count @activities.total_count
  json.current_page @activities.current_page
end

json.payload do
  json.array! @activities do |activity|
    json.partial! 'api/v1/models/crm_deal_activity', formats: [:json], activity: activity
  end
end
