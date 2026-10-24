# frozen_string_literal: true

json.id pipeline.id
json.name pipeline.name
json.description pipeline.description
json.stages_count pipeline.stages.size
json.deals_count pipeline.deals.select { |deal| deal.discarded_at.nil? }.size
json.created_at pipeline.created_at
json.updated_at pipeline.updated_at
