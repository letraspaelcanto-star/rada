# frozen_string_literal: true

require_relative 'lib/agency_crm/version'

Gem::Specification.new do |spec|
  spec.name          = 'agency_crm'
  spec.version       = AgencyCrm::VERSION
  spec.authors       = ['Rada (fork de Chatwoot CE)']
  spec.summary       = 'Módulo CRM (pipeline kanban de deals) para el modelo de agencia multi-cliente'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files         = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 7.0'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
