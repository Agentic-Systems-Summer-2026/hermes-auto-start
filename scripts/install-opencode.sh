#!/usr/bin/env bash
# Install OpenCode via the official installer (https://opencode.ai/install).
# The installer places the binary in $HOME/.opencode/bin (or $HOME/.local/bin if
# XDG_BIN_DIR is set to that path).  On failure it retries up to 3 times.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/_env.sh" 2>/dev/null || true

# Healthy = on PATH and the CLI responds.
integrity_ok() {
  command -v opencode >/dev/null 2>&1 || return 1
  opencode --version >/dev/null 2>&1 || return 1
  return 0
}

if integrity_ok; then
  echo "OpenCode already installed and healthy: $(opencode --version 2>/dev/null)"
  exit 0
fi

for attempt in 1 2 3; do
  echo "==> OpenCode install attempt ${attempt}/3…"
  # Prefer ~/.local/bin so it lands on a well-known PATH dir.
  mkdir -p "${HOME}/.local/bin"
  XDG_BIN_DIR="${HOME}/.local/bin" \
    bash -c 'curl -fsSL --proto "=https" --tlsv1.2 https://opencode.ai/install | bash' || true

  # Reload PATH so the newly installed binary is visible.
  # shellcheck disable=SC1091
  source "${HERE}/_env.sh" 2>/dev/null || true

  if integrity_ok; then
    echo "✓ OpenCode installed and verified: $(opencode --version 2>/dev/null)"
    exit 0
  fi
  echo "   install looked incomplete — cleaning and retrying…"
  rm -f "${HOME}/.local/bin/opencode" "${HOME}/.opencode/bin/opencode" 2>/dev/null || true
done

echo "✗ OpenCode install failed after 3 attempts."
echo "  Manual: curl -fsSL https://opencode.ai/install | bash"
exit 1
