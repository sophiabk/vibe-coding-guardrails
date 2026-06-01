# CLAUDE.md

> **Template note:** This is an anonymized version of a real handoff rulebook. In the
> source project it named two people — *the operator* (a non-technical founder who runs
> and merges her own PRs) and *the original developer* (available only for paid sessions).
> Adapt the names, paths, and escalation channels to your own project. This file is read
> by Claude Code on every session; keep it at the repo root.

**Operator:** the non-technical founder. They merge their own PRs. There is no other human in the review loop.

This file encodes the rules for working on **acme-app**. **Follow it strictly.**

## Project overview

acme-app is a Next.js + Prisma SaaS. Stripe handles billing, NextAuth + Google OAuth handles login, Trigger.dev runs background jobs, and Vercel hosts the app. Postgres lives in Docker locally; a managed Postgres in staging/prod.

## How to run locally

```bash
make dev
```

That's it. Don't run `yarn dev`, `next dev`, `prisma migrate`, or `docker-compose up` directly — `make dev` orchestrates them all and injects secrets via the secrets manager at runtime. If `make dev` fails, run `make doctor` to identify the missing prerequisite. See `docs/debugging.md` for common errors.

## Forbidden actions

These rules apply to changes made through Claude Code in this repo.

> Items tagged **(CI-enforced)** are blocked by `handoff-guards.yml` and cannot be merged. The rest depend on you following the rule.

1. **No changes to `prisma/schema.prisma`.** The database schema is frozen. **(CI-enforced)**
2. **No new dependencies in `package.json`.** No additions, upgrades, or removals from `dependencies` or `devDependencies`. **(CI-enforced)**
3. **No deletions in changes you make.** Don't delete files as part of your edits. If you think a file is dead code, leave it and mention it in the PR description. **Exception:** see "Page removal exception" below.
4. **No edits to authentication code:** `src/auth.js`, `auth.config.ts`, `src/middleware.js`, `src/app/api/auth/**`.
5. **No edits to payment / billing code:** `src/app/api/stripe/**`, `src/lib/get-stripe.js`, `src/lib/stripe-prices.js`.
6. **No edits to background jobs that send messages or call paid APIs** (signup/onboarding/signin emails, contact sync, LLM calls, etc.).
7. **No edits to email / notification code.**
8. **No `git push --force`. No `--no-verify`. No branch deletions.**
9. **Do not edit as a side effect of unrelated work:** `.github/workflows/`, `Makefile`, `CLAUDE.md`, `docs/debugging.md`. These are operational guardrails. They may only be edited when the task explicitly requires touching them.
10. **No running migrations against a remote database.** `prisma migrate deploy` runs automatically on deploy — that is the only path.
11. **No editing secrets in `staging` or `production` environments.** `dev` environment only.

If a bug requires touching any of the above to fix, **stop**. See "Escalation path".

## Refusal protocol

Before starting any change, check:

1. Does the fix touch a forbidden path? → **stop**, write up the issue, point to the escalation path.
2. Does the fix need more than ~3 files? → **stop**, explain why before continuing. **Exception:** "Page removal exception".
3. Are you guessing, or have you reproduced the bug? → if guessing, **stop** and reproduce first.
4. Could a smaller, more obvious fix work? → prefer it, even if less elegant.

Refusing is a feature. Better to leave a bug unfixed than to introduce a worse one.

## Scope discipline

Touch only the files needed to fix the reported bug.

- If the fix appears to need more than ~3 files, stop and explain why. **Exception:** "Page removal exception".
- If the fix appears to require any forbidden action above, stop. Do not look for a workaround.
- Don't refactor adjacent code. Don't "clean up" comments or formatting in files you weren't asked to touch.
- Don't add abstractions, configuration knobs, or helpers that weren't asked for.

## Page removal exception

When the task is **deliberate removal of a page or route** that the operator has asked to delete:

- The ~3-files cap does **not** apply. Touch every file that references the page — imports, links, nav, sitemap, redirects, tests.
- Forbidden action #3 ("no deletions") does **not** apply to the page's own files and to references that exist solely to point at it.

This exception only applies when the operator has explicitly asked to remove a specific page/route. It does **not** cover deleting suspected dead code, removing a page as a side effect of an unrelated fix, or any forbidden path (auth, payment, message jobs, email).

In the PR description, group changes as "page files removed" vs. "references cleaned up".

## Reachability check

The repo contains code paths that look real but aren't reached at runtime — old features, orphaned routes, helpers whose callers were removed. Before flagging or fixing a bug in any function/file, **verify it's actually in use**:

1. `grep` for the function name, route path, or exported symbol.
2. Check there's at least one live caller reachable from a real entry point (an exported page, API route, or background job).
3. If you find no live callers, **don't flag it as a bug** — report it as *possibly dead code* and let the operator decide.

## When prod is broken: roll back first, debug second

If users are reporting a broken production app, **do not push a forward fix.** Roll back to the last known good deployment first, then debug locally. See `docs/debugging.md` § 1.

## Preferred patterns

Before writing new code, check whether something similar already exists: components in `src/components/`, utilities in `src/lib/`, hooks in `src/hooks/`, API routes in `src/app/api/`. Match the style of the file you're editing.

## When stuck, stop

If you can't figure out a bug, or you're going in circles: **stop and report back.** Don't guess. If the bug requires a forbidden action to fix, say so explicitly: "This can't be fixed without modifying `prisma/schema.prisma` / adding a dependency / editing `src/auth.js`. Book a paid session with the developer."

## Escalation path

1. **If prod is broken:** roll back via the host's dashboard (`docs/debugging.md` § 1).
2. **Otherwise:** leave the bug. Add it to a list for the next paid session.
3. **Book a session with the developer** — emergency channel for prod-down/data-corruption/security, scheduled channel for everything else. (Contact details live outside this repo.)

## PR conventions

- **Branch naming:** `fix/short-description` for bug fixes, `ui/short-description` for UI tweaks.
- **PR target:** branch off `staging`, PR back into `staging`. Never PR directly to `main` — CI blocks that anyway.
- **PR description:** use the template — what changed, why, files touched, how you tested locally, screenshots for UI changes.
- **Before merging:** all checks must be green. The `Handoff guards` check enforces the schema/dependency freeze and cannot be overridden.
