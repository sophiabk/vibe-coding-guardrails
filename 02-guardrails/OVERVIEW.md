# Guardrails: making it hard to ship a dangerous change

When you hand a codebase to a non-technical owner (or let an AI assistant make changes), the risk isn't day-to-day edits — it's the *rare catastrophic* one: a database schema change that corrupts data, a dependency bump that breaks the build, a tweak to auth or billing, a direct push to production. These guardrails are designed so that those specific changes are **blocked or gated**, while ordinary work (copy edits, UI tweaks, bug fixes) flows freely.

## The layers of defense

Guardrails are layered from softest (easy to bypass, catches honest mistakes early) to hardest (server-enforced, catches the dangerous stuff):

| Layer | File(s) | What it does | Bypassable by |
| --- | --- | --- | --- |
| **AI rulebook** | `CLAUDE.md` | Tells the AI assistant which files are off-limits and to stop & escalate instead of forcing a risky fix | A human ignoring it |
| **Pre-commit hook** | `.husky/pre-commit` + `lint-staged` | Auto-formats and lint-checks staged files before they're committed | `git commit --no-verify` |
| **CI: freezes** | `.github/workflows/handoff-guards.yml` | Fails any PR that edits `prisma/schema.prisma` or `package.json` dependencies | Nobody (once required) |
| **CI: branch flow** | `.github/workflows/enforce-staging-to-main.yml` | Forces `feature → staging → main`; blocks direct-to-main PRs | Nobody (once required) |
| **CI: quality** | `lint.yml`, `test.yml`, `build.yml`, `deploy.yml` | Lint + Prettier + tests on every push; build + migrate + deploy only on `staging`/`main` | Nobody (once required) |
| **Human gate** | `.github/CODEOWNERS` + branch protection | Requires review from a security team on sensitive paths | A repo admin |

The principle: **a casual mistake hits a soft layer and gets a friendly message; a dangerous mistake hits a hard layer and cannot merge.**

---

## 1. The AI rulebook — `CLAUDE.md`

Read by the AI assistant on every session. It's *advisory* (an LLM can technically do anything it has tool access to), but it shapes behavior strongly. Key sections:

- **Forbidden actions** — explicit file lists that must never be touched: schema, dependencies, auth (`src/auth.js`, `middleware.js`, the auth API routes), billing (`api/stripe/**`), message-sending background jobs, email code. Items also enforced by CI are tagged **(CI-enforced)**.
- **Refusal protocol** — before any change, check: does it touch a forbidden path? does it need >3 files? is the bug actually reproduced? could a smaller fix work? "Refusing is a feature."
- **Reachability check** — the repo contains dead code that *looks* live. Before flagging or fixing a bug, confirm there's a real caller. Don't waste effort fixing unreachable code.
- **Page-removal exception** — the >3-files cap and the no-deletions rule relax *only* when the explicit task is deleting a page/route.
- **Roll back first** — if prod is broken, revert the deploy before debugging forward.
- **Escalation path** — when a fix needs a forbidden action, stop and route to the developer instead of forcing it.

The power of this file is that it converts "please be careful" into a concrete, checkable list. Adapt the path lists to your own codebase.

## 2. Pre-commit hook — `.husky/pre-commit` + `lint-staged`

A one-liner (`npx lint-staged`) that runs on every `git commit`. `lint-staged` (configured in `package.json`) runs ESLint `--fix` and Prettier on just the staged files. This keeps formatting consistent and catches lint errors *before* they reach CI — fast feedback on the author's machine. See [`lint-staged.md`](lint-staged.md).

> This is the only layer a determined author can skip (`--no-verify`), which is why the same checks also run in CI.

## 3. The freezes — `handoff-guards.yml`

The most important CI workflow. It runs on every PR to `staging` or `main` and hard-fails if:

- **The Prisma schema changed.** Detected with an exact-path diff:
  ```bash
  git diff --name-only <base>...HEAD | grep -qx 'prisma/schema.prisma'
  ```
- **Dependencies changed.** It extracts just the `dependencies` and `devDependencies` from `package.json` on both sides, normalizes them with `jq -S` (sorted keys), and string-compares:
  ```bash
  base=$(git show <base>:package.json | jq -S '{dependencies, devDependencies}')
  head=$(git show HEAD:package.json | jq -S '{dependencies, devDependencies}')
  [ "$base" != "$head" ] && exit 1
  ```
  Normalizing with `jq` means reordering or reformatting won't trip it — only a real add/remove/version change does.

These two changes are exactly the ones a non-technical owner can't safely make alone, so the freeze forces a conversation (a "paid session" in the source project) before they can land.

## 4. Branch flow — `enforce-staging-to-main.yml`

Enforces a promotion path so nothing reaches production unreviewed in staging first:

- PRs **to `staging`** — allowed from any branch.
- PRs **to `main`** — allowed **only** from `staging`.
- Anything else targeting `main` fails.

This guarantees `feature → staging → main` and makes "oops I PR'd straight to production" impossible.

## 5. Quality + deploy — `lint.yml`, `test.yml`, `build.yml`, `deploy.yml`

- `lint.yml`, `test.yml`, `build.yml` are **reusable workflows** (`on: workflow_call`) so they can be composed.
- `deploy.yml` runs on every branch push: it always runs lint + test, and **only on `main`/`staging`** does it run database migrations, build, and deploy (to Vercel) — gated by GitHub **Environments** (`Production` vs `Staging`) so production secrets are only available on the `main` ref.
- Migrations run automatically on deploy (`npx prisma migrate deploy`) — the operator never runs a migration against a remote database by hand.

## 6. The human gate — `CODEOWNERS`

Lists security-sensitive paths (auth, schema, migrations, infra, CI config) and assigns a required reviewer team. **Caveat baked into the file:** CODEOWNERS only *requests* review until you turn on branch protection that *requires* CODEOWNERS approval. Without that, GitHub silently skips it.

---

## Turning it on

The CI workflows and CODEOWNERS are inert until you enforce them in GitHub:

1. **Settings → Branches → Branch protection rules** for `main` and `staging`:
   - ✅ Require a pull request before merging.
   - ✅ Require status checks to pass — select **Handoff guards**, **Enforce staging to main**, and your lint/test checks as *required*.
   - ✅ Require review from Code Owners (for the CODEOWNERS rules to bite).
   - ✅ Include administrators (optional but recommended — otherwise an admin can bypass everything).
2. **Create the CODEOWNERS team** (e.g. `@acme-app/security-reviewers`) with write access, or GitHub ignores the rule.
3. **Configure GitHub Environments** (`Production`, `Staging`) with their secrets, so `deploy.yml`'s environment gating works.

Until step 1 is done, these files document intent but don't block anything.
