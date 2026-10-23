# frozen_string_literal: true

require File.expand_path('../../../spec/rails_helper', __dir__)

# Helpers compartidos de los specs del engine AgencyCrm.
# Convencion: los nombres llevan prefijo agency para no colisionar con
# helpers del host si en el futuro se mueven de lugar.
module AgencyCrmSpecHelpers
  def create_agency_pipeline(account, name: 'Pipeline principal')
    AgencyCrm::Pipeline.create!(account: account, name: name)
  end

  def create_agency_stage(pipeline, name: 'Etapa', **attrs)
    AgencyCrm::PipelineStage.create!({ account: pipeline.account, pipeline: pipeline, name: name }.merge(attrs))
  end
end

RSpec.configure do |config|
  config.include AgencyCrmSpecHelpers
end
