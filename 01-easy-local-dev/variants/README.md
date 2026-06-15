# Makefile variants — same flow, different secrets manager

The `Makefile`s in [`../minimal/`](../minimal/) and [`../advanced/`](../advanced/) use
**Infisical** to inject secrets at runtime. The pattern is tool-agnostic: every
secret-needing command is just prefixed with a `SECRETS_RUN` wrapper. To switch tools
you change **one line**.

These variants are complete, minimal-scope `Makefile`s (Docker + Node checks, then
`db-up → migrate → seed → dev`) that differ only in how secrets are injected. Pick one,
rename it to `Makefile`, and drop it in your repo.

| File | Secrets manager | The one line that changes |
| --- | --- | --- |
| `Makefile.infisical` | Infisical | `SECRETS_RUN := infisical run --env=$(ENV) --` |
| `Makefile.doppler` | Doppler | `SECRETS_RUN := doppler run --config $(ENV) --` |
| `Makefile.1password` | 1Password CLI | `SECRETS_RUN := op run --env-file=.env.$(ENV) --` |
| `Makefile.plain-env` | A local `.env` file (no manager) | `SECRETS_RUN :=` (empty) + `set -a; . ./.env` |

> `Makefile.infisical` is identical to `../minimal/Makefile` — included here so all four
> live side by side for comparison.

## Which should I pick?

- **Just getting started / solo project:** `Makefile.plain-env`. Simplest, no extra CLI.
  The tradeoff: secrets live in a `.env` file on disk, so keep it `.gitignore`d. For local
  dev you can seed throwaway values up front — e.g. `AUTH_SECRET=$(openssl rand -base64 32)`
  and any local `PG_PASSWORD` — so `make dev` works with zero hand-editing.
- **Team, want secrets out of files:** `Makefile.infisical` or `Makefile.doppler`.
  Secrets are pulled from a central vault at runtime; nothing on disk to leak.
- **Already in the 1Password ecosystem:** `Makefile.1password`. Reads secret
  *references* from a committed `.env.<env>` template and resolves them at runtime.
