# frozen_string_literal: true

json.payload do
  json.partial! 'api/v1/models/crm_pipeline', formats: [:json], pipeline: @pipeline

  json.stages do
    json.array! @pipeline.stages do |stage|
      json.partial! 'api/v1/models/crm_pipeline_stage', formats: [:json], stage: stage

      json.deals do
        json.array! stage.deals.select { |deal| deal.discarded_at.nil? }.sort_by(&:updated_at).reverse.take(100) do |deal|
          json.partial! 'api/v1/models/crm_deal', formats: [:json], deal: deal
        end
      end
    end
  end
end
