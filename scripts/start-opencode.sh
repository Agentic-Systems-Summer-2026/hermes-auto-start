#!/usr/bin/env bash
# Terminal: validate the key, configure OpenCode, then launch it in the foreground.
# If the key check fails, OpenCode is NOT started — you'll be prompted for a key.
# Put OpenCode on PATH FIRST — VS Code task shells don't load ~/.bashrc.
export PATH="${HOME}/.local/bin:${HOME}/bin:${HOME}/.opencode/bin:${HOME}/.cargo/bin:${PATH:-}"
set -uo pipefail
# Extra, image-agnostic resolution (best effort; never fatal).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh" 2>/dev/null || true
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "════════════════════════════════════════════════════"
echo "  OpenCode  (OU AI Sandbox first, OpenRouter fallback)"
echo "════════════════════════════════════════════════════"

# Pre-flight, with an interactive first-run rescue: if no (working) key is
# found and we're in a real terminal, prompt for a key right here instead of
# aborting. Students paste their OU Sandbox key (sk-) or OpenRouter key
# (sk-or-) and startup continues; nothing to rebuild.
_pf_tries=0
until bash "${REPO_DIR}/scripts/preflight.sh"; do
  reason="$(cat "${HOME}/.opencode/.preflight_reason" 2>/dev/null || echo unknown)"
  _pf_tries=$((_pf_tries+1))
  if [[ -t 0 || -t 1 ]] \
     && [[ "${reason}" == "nokey" || "${reason}" == "invalid" ]] && (( _pf_tries <= 3 )); then
    echo
    echo "🔑  Let's fix that right now (attempt ${_pf_tries}/3) — paste ONE key:"
    echo "    • OU AI Sandbox key (starts with sk-) — first choice, from your Sandbox invitation"
    echo "    • OpenRouter key (starts with sk-or-) — also works, from openrouter.ai → Settings → Keys"
    if ! bash "${REPO_DIR}/scripts/set-key.sh"; then
      echo "⛔  No key entered — OpenCode not started. Run 'bash scripts/set-key.sh' any time, then re-run this task."
      exit 1
    fi
    continue
  fi
  echo "⛔  OpenCode aborted — key pre-flight failed (see message above)."
  exit 1
done

if ! command -v opencode >/dev/null 2>&1; then
  echo "⚙️  opencode not found — installing it now (one-time, ~1-2 min)…"
  bash "${REPO_DIR}/scripts/install-opencode.sh" || true
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh" 2>/dev/null || true
fi
if ! command -v opencode >/dev/null 2>&1; then
  echo "fail" > "${HOME}/.opencode/.preflight"
  echo "❌ opencode still not found after install attempt."
  echo "   PATH=${PATH}"
  echo "   Fix: open a terminal and run  bash .devcontainer/setup.sh"
  exit 1
fi

# Ensure a valid config exists. Re-render if missing or if the stored
# provider doesn't match the validated one from preflight.
PREF_PROVIDER="$(cat "${HOME}/.opencode/.provider" 2>/dev/null || true)"
if [[ ! -f "${HOME}/.config/opencode/opencode.json" ]]; then
  echo "No config found — rendering defaults…"
  bash "${REPO_DIR}/scripts/configure.sh" || true
else
  cur_provider="$(python3 -c '
import json, sys
try:
    c = json.load(open(sys.argv[1]))
    p = c.get("provider", {})
    if "ou-sandbox" in p: print("litellm")
    elif "openrouter" in p: print("openrouter")
except Exception: pass
' "${HOME}/.config/opencode/opencode.json" 2>/dev/null || true)"
  # If current config uses OpenRouter but OU AI Sandbox validated (or vice versa), re-render.
  if [[ -n "${PREF_PROVIDER}" && -n "${cur_provider}" && "${PREF_PROVIDER}" != "${cur_provider}" ]]; then
    echo "Config provider mismatch — re-pointing at ${PREF_PROVIDER}…"
    OPENCODE_PROVIDER="${PREF_PROVIDER}" bash "${REPO_DIR}/scripts/configure.sh" || true
  fi
fi

# Load persisted secrets into this process so OpenCode can read them.
if [[ -f "${HOME}/.opencode/.env" ]]; then set -a; . "${HOME}/.opencode/.env"; set +a; fi

echo "🚀  Starting OpenCode (Ctrl-C to stop) ..."
exec opencode
