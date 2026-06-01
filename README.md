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
│   └── advanced/           # the full version: + background jobs, webhooks, Python workers
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

## How to reuse this

**For the easy-dev setup:**

1. Start from `01-easy-local-dev/minimal/`. Copy the `Makefile`, `docker-compose.yml`, and `.env.example` into your project. You now have `make dev` / `make stop` / `make reset` / `make doctor`.
2. Pick a secrets manager (Infisical, Doppler, 1Password CLI, …) and wire it into the `SECRETS_RUN` variable at the top of the `Makefile`.
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
