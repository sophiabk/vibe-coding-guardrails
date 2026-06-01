# acme-app local development (full version).
# All targets that need secrets run through `infisical run` so secrets are
# injected at runtime — there is no .env file in this workflow.
#
# Common entry points:
#   make dev      — start everything (Docker, migrations, seed, Next, background jobs)
#   make stop     — stop Docker (preserves the database)
#   make reset    — wipe local DB, re-migrate, re-seed
#   make doctor   — check that all prerequisites are installed and authenticated

.PHONY: dev stop reset doctor _hooks _check-docker _check-node _check-yarn _check-infisical _check-trigger _check-stripe _check-python _check-nc _venv _db-up _migrate _seed

INFISICAL_ENV ?= dev
INFISICAL_RUN := infisical run --env=$(INFISICAL_ENV) --

# ---------- main targets ----------

dev: doctor _hooks _db-up _venv _migrate _seed
	@echo ""
	@echo "→ Starting Next.js + background jobs (secrets via Infisical)"
	@echo "  App will be available at http://localhost:3000"
	@echo "  Press Ctrl+C to stop."
	@echo ""
	@$(INFISICAL_RUN) yarn dev

stop:
	@echo "→ Stopping Docker containers"
	@PG_PASSWORD=dummy docker compose down

reset: doctor
	@echo "→ Resetting local database (drops, re-migrates, re-seeds)"
	@$(MAKE) _db-up
	@$(INFISICAL_RUN) npx prisma migrate reset --force
	@echo "✓ Local database reset"

# ---------- doctor ----------

doctor: _check-docker _check-node _check-yarn _check-infisical _check-trigger _check-stripe _check-python _check-nc
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
	@if ! docker compose version > /dev/null 2>&1; then \
		echo "✗ 'docker compose' (v2 plugin) not available."; \
		echo "  Fix: update Docker Desktop to a recent version — the Compose v2 plugin ships with it."; \
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

_check-yarn:
	@echo "→ Checking Yarn (via Corepack)"
	@if ! command -v corepack > /dev/null 2>&1; then \
		echo "✗ Corepack not found."; \
		echo "  Fix: corepack ships with Node 20+. Reinstall Node: brew reinstall node@20"; \
		exit 1; \
	fi
	@corepack enable > /dev/null 2>&1 || true
	@if ! yarn --version > /dev/null 2>&1; then \
		echo "✗ Yarn not available."; \
		echo "  Fix: corepack enable && corepack prepare yarn@4.5.0 --activate"; \
		exit 1; \
	fi

_check-infisical:
	@echo "→ Checking Infisical CLI"
	@if ! command -v infisical > /dev/null 2>&1; then \
		echo "✗ Infisical CLI not installed."; \
		echo "  Fix: brew install infisical/get-cli/infisical"; \
		exit 1; \
	fi
	@if ! infisical user > /dev/null 2>&1; then \
		echo "✗ Infisical CLI not authenticated."; \
		echo "  Fix: run 'infisical login' and follow the browser flow."; \
		exit 1; \
	fi
	@if [ ! -f .infisical.json ]; then \
		echo "✗ .infisical.json not found in repo."; \
		echo "  This file links the repo to the approved Infisical project for local development."; \
		echo "  Fix: ask the original developer for the committed .infisical.json."; \
		echo "  Do not run 'infisical init' and commit a newly generated .infisical.json blindly —"; \
		echo "  'infisical run' would otherwise target whichever project the CLI was last logged into."; \
		exit 1; \
	fi

_check-trigger:
	@echo "→ Checking background-job CLI auth (Trigger.dev)"
	@if ! npx --no-install trigger whoami > /dev/null 2>&1; then \
		echo "✗ Trigger.dev CLI is not authenticated."; \
		echo "  Without this, 'trigger dev' will build a local worker but never"; \
		echo "  register with the cloud — runs queue forever and expire after 10m."; \
		echo "  Fix: run 'npx trigger login' and follow the browser flow."; \
		exit 1; \
	fi

_check-stripe:
	@echo "→ Checking Stripe CLI"
	@if ! command -v stripe > /dev/null 2>&1; then \
		if ! command -v brew > /dev/null 2>&1; then \
			echo "✗ Stripe CLI not installed and Homebrew not available to auto-install it."; \
			echo "  Fix: install Homebrew from https://brew.sh, then run 'make dev' again."; \
			exit 1; \
		fi; \
		echo "  Stripe CLI not found — installing via Homebrew..."; \
		if ! brew install stripe/stripe-cli/stripe; then \
			echo "✗ 'brew install stripe/stripe-cli/stripe' failed."; \
			exit 1; \
		fi; \
	fi
	@if ! stripe config --list 2>/dev/null | grep -q "_api_key"; then \
		echo "✗ Stripe CLI is not authenticated."; \
		echo "  Fix: run 'stripe login' and follow the browser flow."; \
		exit 1; \
	fi

_check-python:
	@echo "→ Checking Python 3"
	@if ! command -v python3 > /dev/null 2>&1; then \
		echo "✗ python3 not installed."; \
		echo "  Fix: brew install python@3.11"; \
		exit 1; \
	fi

_check-nc:
	@echo "→ Checking nc (used by _db-up to probe Postgres on localhost:5432)"
	@if ! command -v nc > /dev/null 2>&1; then \
		echo "✗ nc not installed."; \
		echo "  Fix: macOS ships nc by default. On Linux: 'sudo apt install netcat-openbsd' or your distro's equivalent."; \
		exit 1; \
	fi

# ---------- internals ----------

_hooks: doctor
	@if [ ! -d node_modules ]; then \
		echo "→ node_modules missing — running yarn install"; \
		yarn install --immutable; \
	fi
	@hooks_path="$$(git config --get core.hooksPath 2>/dev/null || true)"; \
	if [ "$$hooks_path" != ".husky/_" ]; then \
		echo "→ Installing git hooks (husky)"; \
		npx husky; \
	fi

_db-up:
	@echo "→ Starting Postgres (Docker)"
	@$(INFISICAL_RUN) docker compose up -d
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

_venv:
	@if [ ! -d .venv ]; then \
		echo "→ Creating Python venv (background jobs use Python)"; \
		python3 -m venv .venv; \
		.venv/bin/pip install --quiet --upgrade pip; \
		.venv/bin/pip install --quiet -r requirements.txt; \
		echo "✓ .venv created and requirements installed"; \
	fi

_migrate:
	@echo "→ Applying Prisma migrations to local DB"
	@$(INFISICAL_RUN) npx prisma migrate deploy

_seed:
	@echo "→ Seeding local DB (reference data only — safe to re-run)"
	@$(INFISICAL_RUN) npx prisma db seed
