# frozen_string_literal: true

class AgencyCrm::Engine < Rails::Engine
  isolate_namespace AgencyCrm

  # Las migraciones del engine corren con `rails db:migrate` del host
  initializer :append_migrations do |app|
    host_paths = app.config.paths['db/migrate'].expanded
    config.paths['db/migrate'].expanded.each do |path|
      app.config.paths['db/migrate'] << path unless host_paths.include?(path)
    end
  end

  # Las asociaciones Account↔CRM viven en el engine (AccountExtension), no en
  # app/models/account.rb — la clase upstream roza el límite de ClassLength.
  config.to_prepare do
    Account.include AgencyCrm::AccountExtension
  end
end
