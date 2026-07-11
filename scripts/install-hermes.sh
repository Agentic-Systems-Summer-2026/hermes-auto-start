#!/usr/bin/env bash
# Install Hermes Agent via the OFFICIAL installer (hermes-agent.nousresearch.com/install.sh).
# NOTE: do NOT use `pip install hermes-agent` — that may install an unrelated package.
#
# The official installer handles: uv, Python 3.11, and symlinks `hermes` to ~/.local/bin.
# On failure it fully cleans up and retries (up to 3 attempts).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/_env.sh" 2>/dev/null || true

# Healthy = on PATH and the CLI responds.
integrity_ok() {
  command -v hermes >/dev/null 2>&1 || return 1
  hermes --version >/dev/null 2>&1 || return 1
  return 0
}

if integrity_ok; then
  echo "Hermes Agent already installed and healthy: $(hermes --version 2>/dev/null)"
  exit 0
fi

for attempt in 1 2 3; do
  echo "==> Hermes Agent install attempt ${attempt}/3…"
  # Run the official installer non-interactively.
  HERMES_NO_ONBOARD=1 HERMES_NO_PROMPT=1 \
    bash -c 'curl -fsSL --proto "=https" --tlsv1.2 \
      https://hermes-agent.nousresearch.com/install.sh | bash' || true

  # Reload PATH so the newly linked binary is visible.
  # shellcheck disable=SC1091
  source "${HERE}/_env.sh" 2>/dev/null || true

  if integrity_ok; then
    echo "✓ Hermes Agent installed and verified: $(hermes --version 2>/dev/null)"
    exit 0
  fi
  echo "   install looked incomplete — cleaning and retrying…"
  # Best-effort cleanup of a partial install before retry.
  rm -f "${HOME}/.local/bin/hermes" 2>/dev/null || true
done

echo "✗ Hermes Agent install failed after 3 attempts."
echo "  Manual: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
exit 1
