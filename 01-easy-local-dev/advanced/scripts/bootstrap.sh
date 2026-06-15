#!/usr/bin/env bash
# One-time bootstrap for acme-app local development on macOS (advanced stack).
# Idempotent — safe to re-run.
#
# This is the OPTIONAL auto-installing companion to `make doctor`. `make dev`
# already runs `make doctor`, which DIAGNOSES missing tools and prints the exact
# fix command; this script goes one step further and INSTALLS them for you.
# (The minimal/ stack has no bootstrap — there you rely on `make doctor`.)
#
# Fresh-terminal workflow:
#   1. Install Homebrew (one-time, manual):
#        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#   2. Download + open Docker Desktop (one-time, manual GUI step):
#        brew install --cask docker && open -a Docker
#   3. Clone + cd:
#        git clone https://github.com/your-org/acme-app.git ~/projects/acme-app
#        cd ~/projects/acme-app
#   4. Run this script:
#        ./scripts/bootstrap.sh
#
# It installs node@20, yarn (via corepack), the Infisical and Stripe CLIs, and
# python@3.11 if missing, installs project dependencies, and finishes with
# `make doctor`. Interactive logins (infisical / stripe / trigger) and Docker
# are left to you — the script points you at each.

set -euo pipefail

cyan='\033[36m'; green='\033[32m'; yellow='\033[33m'; red='\033[31m'; reset='\033[0m'
say()  { printf "${cyan}→${reset} %s\n" "$1"; }
ok()   { printf "${green}✓${reset} %s\n" "$1"; }
warn() { printf "${yellow}!${reset} %s\n" "$1"; }
err()  { printf "${red}✗${reset} %s\n" "$1" >&2; }

# Must run from the repo root
if [ ! -f Makefile ] || [ ! -f package.json ]; then
  err "Run this from the acme-app repo root."
  exit 1
fi

# 1. Homebrew (must already be installed — it's the one true prerequisite)
if ! command -v brew >/dev/null 2>&1; then
  err "Homebrew not installed."
  echo "  Install with:"
  echo '    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi
ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"

# 2. Node 20+
node_major=0
if command -v node >/dev/null 2>&1; then
  node_major=$(node -v | sed 's/v\([0-9]*\).*/\1/')
fi
if [ "$node_major" -lt 20 ]; then
  say "Installing node@20"
  brew install node@20
  brew link --overwrite --force node@20 || true
fi
ok "node $(node -v)"

# 3. Yarn (via corepack — prefers package.json's "packageManager", else a sane default)
if ! command -v corepack >/dev/null 2>&1; then
  err "corepack not found (should ship with Node 20+). Try: brew reinstall node@20"
  exit 1
fi
corepack enable >/dev/null 2>&1 || true
if ! yarn --version >/dev/null 2>&1; then
  pinned=$(grep -E '"packageManager"' package.json | sed -E 's/.*"yarn@([^"]+)".*/\1/')
  pinned="${pinned:-4.5.0}"
  say "Activating yarn@${pinned} via corepack"
  corepack prepare "yarn@${pinned}" --activate
fi
ok "yarn $(yarn --version)"

# 4. Infisical CLI (the secrets manager — substitute your own if you use a different one)
if ! command -v infisical >/dev/null 2>&1; then
  say "Installing infisical"
  brew install infisical/get-cli/infisical
fi
ok "infisical $(infisical --version 2>/dev/null | awk '{print $NF}')"
if ! infisical user >/dev/null 2>&1; then
  warn "infisical not authenticated — run: infisical login"
fi

# 5. Stripe CLI (webhook listener)
if ! command -v stripe >/dev/null 2>&1; then
  say "Installing stripe"
  brew install stripe/stripe-cli/stripe
fi
ok "stripe $(stripe --version 2>/dev/null | awk '{print $NF}')"
if ! stripe config --list 2>/dev/null | grep -q "_api_key"; then
  warn "stripe not authenticated — run: stripe login"
fi

# 6. Python 3 (background jobs use a Python venv)
if ! command -v python3 >/dev/null 2>&1; then
  say "Installing python@3.11"
  brew install python@3.11
fi
ok "python3 $(python3 --version | awk '{print $2}')"

# 7. Docker Desktop (check only — install is a GUI flow, see header step 2)
if ! command -v docker >/dev/null 2>&1; then
  warn "docker not installed — get Docker Desktop: https://www.docker.com/products/docker-desktop/"
elif ! docker info >/dev/null 2>&1; then
  warn "docker installed but not running — open Docker Desktop (whale icon in the menu bar)"
else
  ok "docker running"
fi

# 8. Trigger.dev auth (the CLI is fetched on demand by npx; just check auth)
if ! npx --no-install trigger whoami >/dev/null 2>&1; then
  warn "Trigger.dev not authenticated — run: npx trigger login"
fi

# 9. Project dependencies
say "Installing project dependencies"
yarn install --immutable
ok "yarn install complete"

# 10. Hand off to the existing doctor target
echo ""
say "Running make doctor"
make doctor

echo ""
ok "Bootstrap complete. Next: make dev"
