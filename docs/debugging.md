# Debugging runbook

When something is wrong with acme-app — local, staging, or production — this is the document. Sections are ordered by urgency: rollback comes first because that's what you'll need most.

> **Template note:** anonymized from a real handoff runbook. Replace the dashboard
> URLs, project names, and escalation channels with your own.

---

## 1. Prod is broken — roll back first

If users are reporting that **app.acme-app.com** is broken, do this first. Do not try to push a fix.

1. Open the Vercel dashboard: https://vercel.com → **acme-app** project → **Deployments** tab.
2. Filter the list to **Production** environment.
3. Find the last deployment from **before** the breakage (green status, timestamp before user reports started).
4. Click the three-dot menu (`⋯`) on that deployment → **Promote to Production**.
5. Confirm. Vercel takes 1–2 minutes to swap.
6. Open https://app.acme-app.com in an incognito window and verify the site loads and you can log in.
7. **Now** debug locally to figure out what broke. Do not push to `main` until you've reproduced and fixed the issue.

If rollback doesn't fix it (the issue is in the database, in Stripe, or in a third-party service), this is an **emergency**. See section 7.

---

## 2. Reproduce the bug locally

Almost every bug fix starts here.

1. `git pull` on the `staging` branch.
2. `make dev` and wait for the app at http://localhost:3000.
3. Reproduce the user's steps. Write them down — you'll need them for the PR description.

If the bug only reproduces in production:

- Get a screenshot from the user.
- Check Sentry first (section 3) for the actual error and stack trace.
- Try reproducing locally with the same browser, the same input, the same account state. Differences in data are the most common cause.

---

## 3. Where logs live

| What you're looking for | Where to find it |
| --- | --- |
| Production / staging app errors and stack traces | **Sentry** → Issues. Filter by environment. |
| Production / staging request logs | **Vercel** → acme-app project → **Logs**. Filter by deployment. |
| Background-job runs (signup emails, contact sync, PDF processing) | **Trigger.dev** dashboard → Runs view. Filter by environment and task name. |
| Local app output | The terminal where `make dev` is running. |
| Local Postgres queries | `infisical run --env=dev -- npx prisma studio` (read-only browser at http://localhost:5555) |

---

## 4. Safe database query patterns

**Read-only, local only.** Use Prisma Studio:

```bash
infisical run --env=dev -- npx prisma studio
```

This opens a browser-based DB viewer at `http://localhost:5555`. Browse tables, view rows, see relationships. Read-only is safest — don't edit rows here unless the developer walked you through it.

**Never:**

- Run raw SQL against staging or production databases.
- Set `DATABASE_URL` to a remote URL and run any Prisma command.

---

## 5. Testing background jobs without firing real side effects

Background jobs send email, sync contacts to a marketing list, post to Slack, and call paid LLM APIs.

**Safe:** run jobs locally via `make dev`. Local runs use the `dev` job-runner environment, which is isolated.

**Unsafe:** triggering jobs against staging or production. Those environments are wired to live external services — testing a signup or contact-sync flow there will send real emails, sync to the real audience, or post to the real Slack channel.

If you need to verify a job worked:

- Run it locally first.
- Check the job-runner dashboard's **Runs** view for the dev environment.
- For prod issues, read the existing run logs — don't re-trigger.

---

## 6. Common errors and fixes

| Error | Fix |
| --- | --- |
| `infisical: command not found` | `brew install infisical/get-cli/infisical`, then `infisical login`. |
| `infisical: not authenticated` / `expired token` | `infisical login` and follow the browser flow. Re-run `make dev`. |
| `Cannot connect to the Docker daemon` | Open Docker Desktop. Wait for the whale icon. Re-run `make dev`. |
| `connect ECONNREFUSED 127.0.0.1:5432` (Postgres refused) | `make stop && make dev`. If still failing, `docker compose logs db`. |
| `Error: P3009` or migration drift errors from Prisma | `make reset` (wipes local DB, re-migrates). Safe — local data is throwaway. |
| `Port 3000 is already in use` | `lsof -ti:3000 \| xargs kill -9`, then `make dev`. |
| Node version mismatch / Yarn errors | `node -v` should print v20.x. If not, `brew install node@20 && brew link --overwrite node@20`. Then `corepack enable`. |
| `.infisical.json not found` | Should be committed to the repo. If missing, ask the developer — don't run `infisical init` and commit blindly. |
| Background jobs fail to start with a Python error | The `.venv` is broken or `requirements.txt` changed. Delete `.venv`, then `make dev` rebuilds it. |
| ESLint or Prettier blocking commit (husky) | Run `yarn lint --fix && yarn prettier --write src/`. If it still fails, the lint error is real — read it and fix the line. |

If your error isn't here and rebooting doesn't help: see section 7.

---

## 7. When to stop and escalate

Two contact paths. Pick based on whether users are currently affected.

### Emergency — fast response

Use when:

- **Production is down** and rollback (section 1) didn't fix it.
- **Suspected data corruption** (wrong data, missing data, users seeing other users' data).
- **Security incident** (leaked API key, suspicious account access, suspected breach).

**Contact:** the emergency channel established at handoff. Details are kept outside this repo.

### Scheduled session — planned

Use when:

- A bug fix requires changes to `prisma/schema.prisma`, `package.json` dependencies, or any forbidden file in `CLAUDE.md`.
- A feature is bigger than a small UI tweak.
- You've been stuck for 30+ minutes and want a second pair of eyes.

**Contact:** book through the channel established at handoff.

### What to send when you book

- The bug or task in plain English.
- Steps to reproduce (if a bug).
- A screenshot or screen recording for a visual bug.
- The PR or branch name if you've started.
- Any error messages from Sentry, Vercel logs, or your terminal.

The more context up front, the less time gets spent on triage.
