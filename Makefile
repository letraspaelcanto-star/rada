# Variables
APP_NAME := chatwoot
RAILS_ENV ?= development

# Targets
setup:
	gem install bundler
	bundle install
	pnpm install

db_create:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:create

db_migrate:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:migrate

db_seed:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:seed

db_reset:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:reset

db:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:chatwoot_prepare

console:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails console

server:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails server -b 0.0.0.0 -p 3000

burn:
	bundle && pnpm install

run:
	@if [ -f ./.overmind.sock ]; then \
		echo "Overmind is already running. Use 'make force_run' to start a new instance."; \
	else \
		overmind start -f Procfile.dev; \
	fi

force_run:
	@echo "Cleaning up Overmind processes..."
	@lsof -ti:3036 2>/dev/null | xargs kill -9 2>/dev/null || true
	@lsof -ti:3000 2>/dev/null | xargs kill -9 2>/dev/null || true
	@rm -f ./.overmind.sock
	@rm -f tmp/pids/*.pid
	@echo "Cleanup complete"
	overmind start -f Procfile.dev

force_run_tunnel:
	lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	rm -f ./.overmind.sock
	rm -f tmp/pids/*.pid
	overmind start -f Procfile.tunnel

debug:
	overmind connect backend

debug_worker:
	overmind connect worker

docker: 
	docker build -t $(APP_NAME) -f ./docker/Dockerfile .

.PHONY: setup db_create db_migrate db_seed db_reset db console server burn docker run force_run force_run_tunnel debug debug_worker

# --- Fork (Rada / agency_crm). Ver AGENTS.md "Comandos". Lo que corre acá es lo que corre en CI.
FORK_RUBY := engines/agency_crm app/controllers/api/v1/accounts/crm app/policies/agency_crm app/channels/agency_crm app/views/api/v1/accounts/crm lib/tasks/agency_crm.rake
FORK_SPECS := engines/agency_crm/spec spec/controllers/api/v1/accounts/crm spec/channels/agency_crm spec/policies/agency_crm spec/lib/tasks/rake
FORK_JS := app/javascript/dashboard/api/crmPipelines.js app/javascript/dashboard/api/crmDeals.js app/javascript/dashboard/stores/agencyCrm.js app/javascript/dashboard/stores/specs/agencyCrm.spec.js app/javascript/dashboard/composables/useCrmPipelineCable.js app/javascript/dashboard/routes/dashboard/crm
CORE_REGRESSION := spec/models/conversation_spec.rb spec/models/contact_spec.rb spec/controllers/api/v1/accounts/conversations_controller_spec.rb

fork-lint:
	bundle exec rubocop $(FORK_RUBY)
	pnpm exec eslint $(FORK_JS)

fork-test:
	RAILS_ENV=test bundle exec rspec $(FORK_SPECS) --format documentation
	pnpm exec vitest run app/javascript/dashboard/stores/specs/agencyCrm.spec.js

fork-ci: fork-lint fork-test
	RAILS_ENV=test bundle exec rspec $(CORE_REGRESSION)

.PHONY: fork-lint fork-test fork-ci
