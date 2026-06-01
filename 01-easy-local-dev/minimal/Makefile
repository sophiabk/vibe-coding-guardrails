# acme-app — minimal local development.
#
# The smallest setup that gives a non-technical operator a single command to
# run the whole app. Everything that needs secrets runs through a secrets-manager
# CLI so there is no .env file to hand-edit or accidentally commit.
#
# Common entry points:
#   make dev      — start everything (Docker, migrations, seed, the app)
#   make stop     — stop Docker (preserves the database)
#   make reset    — wipe local DB, re-migrate, re-seed
#   make doctor   — check that all prerequisites are installed

.PHONY: dev stop reset doctor _check-docker _check-node _db-up _migrate _seed

# ---------- secrets manager ----------
# This wrapper injects secrets at runtime. Point it at whatever you use:
#   Infisical:    infisical run --env=$(ENV) --
#   Doppler:      doppler run --config $(ENV) --
#   1Password:    op run --env-file=.env.$(ENV) --
# The rest of the Makefile just prefixes secret-needing commands with $(SECRETS_RUN).
ENV ?= dev
SECRETS_RUN := infisical run --env=$(ENV) --

# ---------- main targets ----------

dev: doctor _db-up _migrate _seed
	@echo ""
	@echo "→ Starting the app (secrets injected at runtime)"
	@echo "  App will be available at http://localhost:3000"
	@echo "  Press Ctrl+C to stop."
	@echo ""
	@$(SECRETS_RUN) yarn dev

stop:
	@echo "→ Stopping Docker containers"
	@PG_PASSWORD=dummy docker compose down

reset: doctor
	@echo "→ Resetting local database (drops, re-migrates, re-seeds)"
	@$(MAKE) _db-up
	@$(SECRETS_RUN) npx prisma migrate reset --force
	@echo "✓ Local database reset"

# ---------- doctor ----------

doctor: _check-docker _check-node
	@echo "✓ All prerequisites OK"

_check-docker:
	@echo "→ Checking Docker"
	@if ! command -v docker > /dev/null 2>&1; then \
		echo "✗ Docker not installed."; \
		echo "  Fix: install Docker Desktop from https://www.docker.com/products/docker-desktop/"; \
		exit 1; \
	fi
	@if ! docker info > /dev/null 2>&1; then \
		echo "✗ Docker is installed but not running."; \
		echo "  Fix: open Docker Desktop and wait for the whale icon to appear in the menu bar."; \
		exit 1; \
	fi

_check-node:
	@echo "→ Checking Node version"
	@node_major=$$(node -v 2>/dev/null | sed 's/v\([0-9]*\).*/\1/'); \
	if [ -z "$$node_major" ]; then \
		echo "✗ Node is not installed."; \
		echo "  Fix: brew install node@20"; \
		exit 1; \
	elif [ "$$node_major" -lt 20 ]; then \
		echo "✗ Node v$$node_major is too old (need 20+)."; \
		echo "  Fix: brew install node@20 && brew link --overwrite node@20"; \
		exit 1; \
	fi

# ---------- internals ----------

_db-up:
	@echo "→ Starting Postgres (Docker)"
	@$(SECRETS_RUN) docker compose up -d
	@echo "  Waiting for Postgres to accept connections on localhost:5432..."
	@for i in $$(seq 1 30); do \
		if nc -z localhost 5432 > /dev/null 2>&1; then \
			echo "✓ Postgres ready"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "✗ Postgres did not become ready in 30 seconds."; \
	echo "  Fix: check 'docker compose logs db' for errors."; \
	exit 1

_migrate:
	@echo "→ Applying Prisma migrations to local DB"
	@$(SECRETS_RUN) npx prisma migrate deploy

_seed:
	@echo "→ Seeding local DB (safe to re-run)"
	@$(SECRETS_RUN) npx prisma db seed
