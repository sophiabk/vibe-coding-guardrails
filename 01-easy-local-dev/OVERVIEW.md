# Easy local dev: one command for a non-technical owner

> **This describes how the pattern works — it is not a runnable repo.** The example app is
> **`acme-app`** and `your-org/acme-app` is a placeholder. The steps below show how the
> `make dev` workflow behaves in a real project that adopts this template; copy the pieces
> into your own app. There is nothing in this template to `make dev` against.

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

`make dev` is the daily ritual *once you're set up*. From a brand-new Mac there are three things to do by hand — install Homebrew, open Docker, and clone the repo — then one command does the rest: the `advanced/` stack ships a `bootstrap.sh` that installs every remaining tool, while the `minimal/` stack leans on `make doctor` to tell you what to install. Skip any step you've already done.

### 1. Install Homebrew

The macOS package manager. Every other tool is installed through it, so this comes first.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Download and open Docker Desktop

The local Postgres database runs in Docker. This is a manual step — it needs a GUI license click, so it's not something a script should do for you.

```bash
brew install --cask docker    # OR download from https://www.docker.com/products/docker-desktop/
open -a Docker                # launch and wait for the whale icon in the menu bar
```

Docker has to be **running** (whale icon visible) before any `make` target that touches the database.

### 3. Clone the repo

```bash
git clone https://github.com/your-org/acme-app.git ~/projects/acme-app
cd ~/projects/acme-app
```

### 4. Install the remaining tools

**Advanced stack — run the bootstrap script:**

```bash
./scripts/bootstrap.sh
```

The `advanced/` stack ships [`scripts/bootstrap.sh`](advanced/scripts/bootstrap.sh) — idempotent, safe to re-run. It installs `node@20`, Yarn (via Corepack), the Infisical and Stripe CLIs, and `python@3.11` if missing, installs project dependencies, and finishes by running `make doctor`. Interactive logins (`infisical login`, `stripe login`, `npx trigger login`) and Docker are left to you — the script points you at each.

> **Minimal stack — no bootstrap.** The `minimal/` stack has no script; skip straight to step 5. `make dev` runs `make doctor`, which *diagnoses* each missing tool and prints the **exact command to fix it** (e.g. `Fix: brew install node@20`). Run it, re-run `make dev`, repeat until green. The error *is* the instructions, so there's no separate list to memorize.

### 5. Authenticate and start — `make dev`

```bash
infisical login    # secrets are injected at runtime; log in once per machine
make dev
```

`make dev` runs `make doctor` first (so anything still missing or unauthenticated is caught with an exact fix), then starts Postgres, applies migrations, seeds, and launches the app + background worker + webhook listener. Once it's green, `make dev` is the only command you need from then on.

## Why this is easy for a non-technical person

Each design choice removes a specific point of friction:

- **One command, not seven.** The operator memorizes `make dev`. The Makefile remembers the order, the flags, and the dependencies between steps.
- **No `.env` file to hand-edit.** Secrets come from the secrets manager at runtime. Nothing to copy-paste, nothing to accidentally commit, nothing to get out of sync between team members.
- **`doctor` diagnoses the machine.** Instead of a cryptic stack trace, a missing tool produces `✗ Docker is installed but not running. Fix: open Docker Desktop…`. The error *is* the instructions.
- **Postgres readiness is handled.** `_db-up` polls the database port for up to 30 seconds instead of racing ahead and failing with a confusing "connection refused". Docker has started before migrations run.
- **The seed is idempotent.** Re-running `make dev` never corrupts data or throws "already exists" errors.
- **Three processes look like one.** `concurrently` runs the app, the worker, and the webhook listener in a single terminal with labeled, color-coded output — no juggling tabs.
- **`make reset` is a safe panic button.** When the local database gets into a weird state, one command rebuilds it from scratch. There's nothing precious to lose locally.

## Layers in this folder

- [`minimal/`](minimal/) — the **generic core**: Next.js + Postgres + a secrets-manager wrapper. Start here. It's the smallest thing that gives you `make dev` / `stop` / `reset` / `doctor`.
- [`advanced/`](advanced/) — the **full version**: adds the background-job worker, the Stripe webhook listener, the Python virtualenv, the complete `doctor` check suite, and [`scripts/bootstrap.sh`](advanced/scripts/bootstrap.sh) (auto-installs the toolchain). Copy pieces from here as your stack grows.
- [`variants/`](variants/) — the **same minimal Makefile, one per secrets manager** (Infisical, Doppler, 1Password, or a plain `.env` file). Shows that switching tools is a one-line change.

The secrets manager is shown as **Infisical** in `advanced/` because that's what the source project used, but the pattern is tool-agnostic — `minimal/` uses a generic `SECRETS_RUN` variable you can point at Doppler, 1Password CLI, `direnv`, or anything else that wraps a command with injected env vars.
