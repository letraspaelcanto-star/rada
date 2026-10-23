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
end
