#!/usr/bin/env bash
# Lifecycle-hook (devcontainer postStartCommand): run a background preflight
# check so the Hermes: Chat terminal can start faster on container restart.
# NOTE: This script is named gateway-daemon.sh for historical compatibility
# (it previously started the OpenClaw gateway). It no longer manages a
# gateway — it is now a preflight startup daemon for Hermes Agent.
# Idempotent: exits immediately if preflight already passed.
# Never fails the container start (always exits 0).
export PATH="${HOME}/.local/bin:${HOME}/.hermes/bin:${HOME}/.cargo/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh" 2>/dev/null || true
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${HOME}/.hermes"
LOG="${HOME}/.hermes/hermes.log"

# Already passed preflight? Nothing to do.
if [[ "$(cat "${HOME}/.hermes/.preflight" 2>/dev/null)" == "ok" ]]; then
  exit 0
fi

# Run preflight in the background so postStartCommand returns quickly.
: > "${LOG}"
{
  echo "[hermes-startup] $(date '+%Y-%m-%d %H:%M:%S %Z') running preflight in background…"
} >> "${LOG}"

if command -v setsid >/dev/null 2>&1; then
  setsid --fork bash "${REPO_DIR}/scripts/preflight.sh" >> "${LOG}" 2>&1 < /dev/null || true
else
  nohup bash "${REPO_DIR}/scripts/preflight.sh" >> "${LOG}" 2>&1 < /dev/null &
  disown 2>/dev/null || true
fi

exit 0
