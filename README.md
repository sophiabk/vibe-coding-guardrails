# Handoff Template — easy local dev + guardrails

A reusable, anonymized starter kit for making a web app **safe to hand off to a non-technical owner** (or to an AI coding assistant) without the wheels coming off.

It distills two ingredients from a real production SaaS handoff:

1. **A one-command local dev setup** — `make dev` hides Docker, database migrations, secret injection, and multi-process orchestration behind a single command. A non-technical operator can run the whole stack without knowing what any of those words mean.
2. **A wall of guardrails** — an AI-assistant rulebook (`CLAUDE.md`), GitHub Actions that freeze the database schema and dependencies, branch-flow enforcement, a pre-commit hook, and CODEOWNERS. Together they make it *hard* to ship a dangerous change, whether the author is a person or an LLM.

The example app is called **`acme-app`** throughout. Every secret value is an obvious placeholder — replace them with your own.

---

## What's in here

```
handoff-template/
├── 01-easy-local-dev/      # "make dev" and why it's non-technical-friendly
│   ├── OVERVIEW.md         # ← read this first
│   ├── minimal/            # generic core: Next.js + Postgres + a secrets manager
│   ├── advanced/           # the full version: + background jobs, webhooks, Python workers
│   └── variants/           # the same Makefile for Doppler / 1Password / plain .env
│
├── 02-guardrails/          # every guardrail, explained, with the actual files
│   ├── OVERVIEW.md         # ← read this first
│   ├── CLAUDE.md           # the AI-assistant rulebook
│   ├── .github/            # workflows, CODEOWNERS, PR template
│   ├── .husky/             # pre-commit hook
│   └── lint-staged.md
│
└── docs/
    └── debugging.md        # the runbook the operator reaches for when something breaks
```

---

## Prerequisites — what to install

These guardrails (and the `make dev` workflow they sit on top of) assume a Mac with the
full stack below installed. A fresh Mac needs these before `make dev` will work. Run them
line by line; skip any you already have. `make doctor` checks every one of these and
prints the exact fix command for anything that's missing.

```bash
# 1. Homebrew — the macOS package manager everything else uses
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. GitHub CLI — clone the (private) repo over HTTPS, no SSH keys
brew install gh
gh auth login                      # interactive: GitHub.com → HTTPS → login with browser

# 3. Docker Desktop — runs the local Postgres database (download + launch)
brew install --cask docker         # OR download https://www.docker.com/products/docker-desktop/
open -a Docker                     # launch and wait for the whale icon in the menu bar

# 4. Node.js 20+ — runs Next.js and the tooling
brew install node@20

# 5. Yarn via Corepack — the package manager
corepack enable
corepack prepare yarn@4.5.0 --activate

# 6. Secrets manager CLI (Infisical in the advanced example) — injects secrets at runtime
brew install infisical/get-cli/infisical
infisical login                    # interactive browser flow, once per machine

# 7. Stripe CLI — forwards webhooks to localhost during dev
brew install stripe/stripe-cli/stripe
stripe login

# 8. Trigger.dev CLI — the background-job worker
npx trigger login                  # auto-installs on first run

# 9. Python 3 — for the PDF-processing background jobs
brew install python@3.11

# 10. netcat (nc) — used to probe Postgres readiness; ships with macOS (no install)
```

Docker has to be **running** (whale icon visible in the menu bar) before any `make` target
that touches the database. The `minimal/` setup only needs steps 1–6; the rest are for the
`advanced/` stack (background jobs, webhooks, Python workers).

## Running it

Once the prerequisites are in place, everything is driven by four `make` commands:

| Command | What it does |
| --- | --- |
| `make dev` | Start everything (Docker + migrate + seed + the dev processes). |
| `make stop` | Stop the Docker containers. **Database data is preserved.** |
| `make reset` | Wipe the local DB, re-migrate, re-seed. (Local data is throwaway.) |
| `make doctor` | Check prerequisites; print the fix command for anything missing. |

If `make dev` fails, run `make doctor` first — the error message *is* the install
instructions. See [`01-easy-local-dev/OVERVIEW.md`](01-easy-local-dev/OVERVIEW.md) for the
narrated, step-by-step first-time walkthrough.

---

## How to reuse this

**For the easy-dev setup:**

1. Start from `01-easy-local-dev/minimal/`. Copy the `Makefile`, `docker-compose.yml`, and `.env.example` into your project. You now have `make dev` / `make stop` / `make reset` / `make doctor`.
2. Pick a secrets manager (Infisical, Doppler, 1Password CLI, …) and wire it into the `SECRETS_RUN` variable at the top of the `Makefile`. See `01-easy-local-dev/variants/` for a ready-made Makefile per tool.
3. As your stack grows, copy the relevant pieces from `01-easy-local-dev/advanced/` — the extra `doctor` checks, the Python `_venv` target, the multi-process `dev` script in `package.json`.

**For the guardrails:**

1. Copy `02-guardrails/.github/` into your repo root. The two that do the heavy lifting are `handoff-guards.yml` (freezes schema + dependencies) and `enforce-staging-to-main.yml` (branch flow).
2. Copy `02-guardrails/CLAUDE.md` to your repo root and edit the forbidden-path lists to match your codebase.
3. Copy `.husky/pre-commit` and add the `lint-staged` block (see `lint-staged.md`) to your `package.json`.
4. **Important:** CI checks and CODEOWNERS only *advise* until you turn on **branch protection** in GitHub (Settings → Branches) and mark the checks as *required*. See `02-guardrails/OVERVIEW.md` § "Turning it on".

---

## The mental model

Think of it as **layers of defense**, from softest to hardest:

| Layer | Where | Stops | Can be bypassed by |
| --- | --- | --- | --- |
| AI rulebook (`CLAUDE.md`) | The assistant's context | The assistant *proposing* a bad change | A human ignoring it |
| Pre-commit hook (husky) | The author's machine | Unformatted / lint-failing commits | `git commit --no-verify` |
| CI checks (GitHub Actions) | Every push / PR | Schema + dependency edits, bad branch flow, failing tests | Nobody, once required |
| Branch protection + CODEOWNERS | GitHub server | Merging without green checks / required review | A repo admin |

No single layer is sufficient. The point is that a casual mistake hits a soft layer early, and a dangerous mistake hits a hard layer before it reaches production.

> This kit is illustrative. The `package.json` dependency lists are examples — pin your own versions.
