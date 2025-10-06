# Variables
APP_NAME := chatwoot
RAILS_ENV ?= development
VITE_PORT ?= 3036

# --- Vite / HMR (com polling para WSL / /mnt) ---
vite:
	BUILD_MODE= \
	CHOKIDAR_USEPOLLING=1 \
	CHOKIDAR_INTERVAL=150 \
	VITE_USE_POLLING=1 \
	VITE_PORT=$(VITE_PORT) \
	VITE_HMR_HOST=127.0.0.1 \
	VITE_RUBY_HOST=0.0.0.0 \
	VITE_RUBY_PORT=$(VITE_PORT) \
	bin/vite dev

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

# Rails + Vite (sem Overmind)
dev: ## Rails + Vite (fallback caso não use Overmind)
	( BUILD_MODE= \
	  CHOKIDAR_USEPOLLING=1 \
	  CHOKIDAR_INTERVAL=150 \
	  VITE_USE_POLLING=1 \
	  VITE_PORT=$(VITE_PORT) \
	  VITE_HMR_HOST=127.0.0.1 \
	  VITE_RUBY_HOST=0.0.0.0 \
	  VITE_RUBY_PORT=$(VITE_PORT) \
	  bin/vite dev ) & \
	RAILS_ENV=$(RAILS_ENV) bundle exec rails server -b 0.0.0.0 -p 3000

kill_ports:
	-lsof -ti:3000,$(VITE_PORT) | xargs -r kill -9 || true
	rm -f ./.overmind.sock
	rm -f tmp/pids/*.pid

debug_vite:
	overmind connect vite

force_run:
	rm -f ./.overmind.sock
	rm -f tmp/pids/*.pid
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

.PHONY: setup db_create db_migrate db_seed db_reset db console server burn docker run force_run force_run_tunnel debug debug_worker vite dev kill_ports debug_vite
