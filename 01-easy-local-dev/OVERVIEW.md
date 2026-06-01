# Easy local dev: one command for a non-technical owner

## The problem

A modern web app has a lot of moving parts. To run `acme-app` locally you need, all at once:

- A **Postgres database** (in Docker).
- The database **migrated** to the latest schema and **seeded** with reference data.
- **Secrets** (API keys, database password, OAuth credentials) available to the app — but *not* sitting in a file on disk where they can leak.
- The **Next.js dev server**.
- A **background-job worker** (Trigger.dev) and a **Stripe webhook listener**, both running in parallel.
- A **Python virtual environment** for the PDF-processing jobs.

Asking a non-technical founder to run `docker compose up`, then `prisma migrate deploy`, then `prisma db seed`, then juggle three terminal tabs — while pasting secrets into an `.env` file — is a recipe for a broken machine and a support call.

## The solution: `make dev`

Everything above collapses into one command:

```bash
make dev
```

There is no `.env` file to manage. Secrets are injected **at runtime** by a secrets-manager CLI (`infisical run --env=dev -- <command>`), so they never touch disk and never get committed.

If the machine is missing a prerequisite, the operator runs:

```bash
make doctor
```

…which checks every tool, and for each missing one prints the **exact command to fix it** (e.g. `brew install node@20`). `doctor` is the "what's wrong with my computer" button.

## What `make dev` actually does

The targets chain together so the operator never has to remember the order:

```
make dev
  ├─ doctor    →  verify Docker, Node 20+, Yarn, the secrets CLI, the job-runner CLI,
  │               the Stripe CLI, Python 3, and netcat are all installed & authenticated
  ├─ _hooks    →  yarn install (if node_modules is missing) + set up git hooks
  ├─ _db-up    →  docker compose up -d, then poll localhost:5432 until Postgres answers
  ├─ _venv     →  create a Python virtualenv and pip install requirements (once)
  ├─ _migrate  →  infisical run -- npx prisma migrate deploy
  ├─ _seed     →  infisical run -- npx prisma db seed   (idempotent — safe to re-run)
  └─ infisical run -- yarn dev
                 └─ concurrently runs THREE processes in one terminal:
                    • next dev          (the app on http://localhost:3000)
                    • trigger dev       (the background-job worker)
                    • stripe listen     (forwards Stripe webhooks to localhost)
```

The other entry points:

| Command | What it does |
| --- | --- |
| `make dev` | Start everything. |
| `make stop` | Stop the Docker containers. **Database data is preserved.** |
| `make reset` | Wipe the local database, re-migrate, re-seed. (Local data is throwaway.) |
| `make doctor` | Check prerequisites and print fixes for anything missing. |

## First-time setup (fresh Mac, nothing installed)

`make dev` is the daily ritual *once you're set up*. The full path from a brand-new Mac with nothing installed looks like this. Skip any step you've already done.

### 1. Install Homebrew

The macOS package manager. Everything else uses it.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install the GitHub CLI and authenticate

Lets you clone the (private) repo over HTTPS without setting up SSH keys.

```bash
brew install gh
gh auth login    # interactive browser flow — pick GitHub.com, HTTPS, login with browser
```

### 3. Install Docker Desktop

The local Postgres database runs in Docker. This is a manual step — it needs sudo and a GUI license click, so it's not something a script should do for you.

```bash
brew install --cask docker    # OR download from https://www.docker.com/products/docker-desktop/
open -a Docker                # launch and wait for the whale icon in the menu bar
```

Docker has to be **running** (whale icon visible) before any `make` target that touches the database.

### 4. Clone the repo

```bash
gh repo clone your-org/acme-app ~/projects/acme-app
cd ~/projects/acme-app
```

### 5. Let `make doctor` tell you what's left

```bash
make doctor
```

`doctor` checks every prerequisite (Node 20+, Yarn, the secrets-manager CLI, Python, etc.) and, for each one that's missing, prints the **exact command to fix it** — e.g. `Fix: brew install node@20`. Run those fix commands, then re-run `make doctor` until it's all green. The error *is* the instructions; there's no separate setup script to memorize.

### 6. Authenticate the secrets manager

Secrets are injected at runtime, so you log in once per machine (Infisical in the `advanced/` example — substitute your own):

```bash
infisical login    # interactive browser flow
```

### 7. Start everything

```bash
make dev
```

From here on, `make dev` is the only command you need.

## Why this is easy for a non-technical person

Each design choice removes a specific point of friction:

- **One command, not seven.** The operator memorizes `make dev`. The Makefile remembers the order, the flags, and the dependencies between steps.
- **No `.env` file to hand-edit.** Secrets come from the secrets manager at runtime. Nothing to copy-paste, nothing to accidentally commit, nothing to get out of sync between team members.
- **`doctor` diagnoses the machine.** Instead of a cryptic stack trace, a missing tool produces `✗ Docker is installed but not running. Fix: open Docker Desktop…`. The error *is* the instructions.
- **Postgres readiness is handled.** `_db-up` polls the database port for up to 30 seconds instead of racing ahead and failing with a confusing "connection refused". Docker has started before migrations run.
- **The seed is idempotent.** Re-running `make dev` never corrupts data or throws "already exists" errors.
- **Three processes look like one.** `concurrently` runs the app, the worker, and the webhook listener in a single terminal with labeled, color-coded output — no juggling tabs.
- **`make reset` is a safe panic button.** When the local database gets into a weird state, one command rebuilds it from scratch. There's nothing precious to lose locally.

## Two layers in this folder

- [`minimal/`](minimal/) — the **generic core**: Next.js + Postgres + a secrets-manager wrapper. Start here. It's the smallest thing that gives you `make dev` / `stop` / `reset` / `doctor`.
- [`advanced/`](advanced/) — the **full version**: adds the background-job worker, the Stripe webhook listener, the Python virtualenv, and the complete `doctor` check suite. Copy pieces from here as your stack grows.

The secrets manager is shown as **Infisical** in `advanced/` because that's what the source project used, but the pattern is tool-agnostic — `minimal/` uses a generic `SECRETS_RUN` variable you can point at Doppler, 1Password CLI, `direnv`, or anything else that wraps a command with injected env vars.
