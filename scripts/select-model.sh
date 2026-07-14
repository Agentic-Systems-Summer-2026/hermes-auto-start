#!/usr/bin/env bash
# Switch the OpenCode model. Browses tool-capable OpenRouter models (your
# own key) and — when an OU AI Sandbox key is present — the OU Sandbox
# catalog (the course's first-choice endpoint). Updates
# ~/.config/opencode/opencode.json and OpenCode picks up the change on
# next startup.
set -uo pipefail
# Make 'opencode' findable in non-interactive shells.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh" 2>/dev/null || true

LITELLM_BASE_URL="${LITELLM_BASE_URL:-https://litellm.lib.ou.edu}"
ENV_FILE="${HOME}/.opencode/.env"
oubase="${LITELLM_BASE_URL%/}"

read_env() { # read_env VAR -> value from process env or ~/.opencode/.env
  local var="$1" val="${!1:-}"
  [[ -z "${val}" && -f "${ENV_FILE}" ]] && val="$(grep -E "^${var}=" "${ENV_FILE}" | tail -n1 | cut -d= -f2- || true)"
  printf '%s' "${val}"
}

apply_model() { # apply_model <provider> <primary>
  local provider="$1" primary="$2"
  echo "→ Setting model: ${primary} (provider: ${provider})"

  CONFIG_DIR="${HOME}/.config/opencode"
  CONFIG_FILE="${CONFIG_DIR}/opencode.json"
  mkdir -p "${CONFIG_DIR}"

  if [[ "${provider}" == "litellm" ]]; then
    # OU AI Sandbox: OpenAI-compatible custom endpoint
    LL_KEY="$(read_env LITELLM_API_KEY)"
    BASE_URL="${oubase}/v1"
    python3 - "${CONFIG_FILE}" "${primary}" "${BASE_URL}" "${LL_KEY}" << 'PY'
import json, sys, os
cfg_file, model, base_url, api_key = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    cfg = json.load(open(cfg_file)) if os.path.exists(cfg_file) else {}
except Exception:
    cfg = {}
cfg["$schema"] = "https://opencode.ai/config.json"
cfg["provider"] = {
    "ou-sandbox": {
        "npm": "@ai-sdk/openai-compatible",
        "name": "OU AI Sandbox",
        "options": {"baseURL": base_url, "apiKey": api_key},
        "models": {model: {"name": model}}
    }
}
cfg["model"] = f"ou-sandbox/{model}"
os.makedirs(os.path.dirname(cfg_file), exist_ok=True)
with open(cfg_file, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
print(f"✅ Model set to: {model}")
print(f"   Config: {cfg_file}")
PY
  else
    # OpenRouter: built-in provider — key from OPENROUTER_API_KEY env var
    OR_KEY="$(read_env OPENROUTER_API_KEY)"
    python3 - "${CONFIG_FILE}" "${primary}" "${OR_KEY}" << 'PY'
import json, sys, os
cfg_file, model, api_key = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    cfg = json.load(open(cfg_file)) if os.path.exists(cfg_file) else {}
except Exception:
    cfg = {}
cfg["$schema"] = "https://opencode.ai/config.json"
cfg["provider"] = {
    "openrouter": {
        "options": {"apiKey": api_key}
    }
}
cfg["model"] = f"openrouter/{model}"
os.makedirs(os.path.dirname(cfg_file), exist_ok=True)
with open(cfg_file, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
print(f"✅ Model set to: {model}")
print(f"   Config: ~/.config/opencode/opencode.json")
PY
  fi
  chmod 600 "${CONFIG_FILE}" 2>/dev/null || true
  echo "   Restart OpenCode (Ctrl-C + bash scripts/start-opencode.sh) to use the new model."
}

# ---- prerequisites --------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Required tool '$1' not found — $2"; exit 1; }; }
need curl    "rebuild the Codespace or install curl."
need python3 "rebuild the Codespace or install python3."

# ---- OpenRouter catalog (primary) -----------------------------------------
OR_KEY="$(read_env OPENROUTER_API_KEY)"
[[ -z "${OR_KEY}" || "${OR_KEY}" == "sk-or-REPLACE_ME" ]] && \
  { echo "No OpenRouter key. Create one at https://openrouter.ai (Settings → Keys), then run: bash scripts/set-key.sh"; exit 1; }

# Validate the key first.
kc="$(curl -s -m 15 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${OR_KEY}" https://openrouter.ai/api/v1/key || echo 000)"
if [[ "${kc}" != "200" ]]; then
  echo "⚠️  OpenRouter key check returned HTTP ${kc} — it may be invalid, disabled, or out of credit."
  echo "    You can still browse, but the model will fail at runtime until the key works."
  read -rp "Continue anyway? [y/N] " yn </dev/tty || yn=""
  [[ "${yn}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

echo "Fetching tool-capable OpenRouter models ..."
if ! curl -fsS -m 30 "https://openrouter.ai/api/v1/models?supported_parameters=tools" -o /tmp/or_models.json; then
  echo "❌ Could not reach OpenRouter (network/endpoint). Try again in a moment."; exit 1
fi
mapfile -t ORROWS < <(python3 - <<'PY'
import json
data = json.load(open("/tmp/or_models.json")).get("data", [])
popular = {"anthropic","openai","google","x-ai","meta-llama","mistralai",
           "qwen","deepseek","z-ai","moonshotai","minimax"}
def perM(v):
    try: return float(v) * 1_000_000
    except Exception: return None
rows = []
for m in data:
    mid = m.get("id", "")
    vendor = mid.split("/")[0] if "/" in mid else mid
    arch = m.get("architecture", {}) or {}
    if "text" not in (arch.get("input_modalities") or []): continue
    if "tools" not in (m.get("supported_parameters") or []): continue
    if vendor not in popular: continue
    pr = m.get("pricing", {}) or {}
    pin, pout = perM(pr.get("prompt")), perM(pr.get("completion"))
    free = (pin == 0 and pout == 0)
    ctx = m.get("context_length") or 0
    ctxs = f"{ctx // 1000}k" if ctx else "?"
    if free: price = "FREE"
    elif pin is not None and pout is not None: price = f"${pin:.2f}/${pout:.2f} /M"
    else: price = "price n/a"
    rows.append((0 if free else 1, pin if pin is not None else 9e9, vendor, mid,
                 f"{price:<16} {mid} ({ctxs})"))
rows.sort(key=lambda r: (r[0], r[1], r[2], r[3]))
rows.insert(0, (0, 0.0, "openrouter", "openrouter/free",
                f"{'FREE':<16} openrouter/free (router -- picks a free, tool-capable model per request; rate-limited)"))
for r in rows: print(f"{r[3]}\t{r[4]}")
PY
)
((${#ORROWS[@]})) || { echo "❌ No tool-capable models returned from OpenRouter."; exit 1; }
OR_IDS=(); i=1
echo; echo "OpenRouter models (tool-capable; free first, then by price — remember it's your own credit):"
for row in "${ORROWS[@]}"; do
  OR_IDS+=("${row%%$'\t'*}")
  printf "  %3d) %s\n" "$i" "${row#*$'\t'}"; ((i++))
done
N=${#OR_IDS[@]}

# ---- OU AI Sandbox option (key-gated; the course's first-choice endpoint) -----
LL_KEY="$(read_env LITELLM_API_KEY)"
[[ "${LL_KEY}" == "sk-REPLACE_ME" ]] && LL_KEY=""
LL_OPTION=0
if [[ -n "${LL_KEY}" ]]; then
  LL_OPTION=$((N+1))
  printf "  %3d) %s\n" "${LL_OPTION}" "OU AI Sandbox (first-choice endpoint, no per-token cost) → browse the LiteLLM catalog"
fi
echo
read -rp "Primary model number [default 1]: " choice </dev/tty; choice="${choice:-1}"

# ---- OU AI Sandbox branch -------------------------------------------------
if [[ -n "${LL_KEY}" && "${choice}" == "${LL_OPTION}" ]]; then
  echo "Fetching OU models from ${oubase} ..."
  http=000
  for url in "${oubase}/v1/models" "${oubase}/models"; do
    http="$(curl -s -m 20 -o /tmp/ou_models.json -w '%{http_code}' -H "Authorization: Bearer ${LL_KEY}" "${url}" || echo 000)"
    [[ "${http}" == "200" ]] && break
  done
  case "${http}" in
    200) ;;
    401|403) echo "❌ OU AI Sandbox key rejected (HTTP ${http})."; exit 1 ;;
    000)     echo "❌ Could not reach ${oubase} (network/endpoint issue). Check the URL or try again."; exit 1 ;;
    *)       echo "❌ OU gateway returned HTTP ${http}. Details in /tmp/ou_models.json"; exit 1 ;;
  esac
  mapfile -t OU < <(python3 -c 'import json
for m in json.load(open("/tmp/ou_models.json")).get("data",[]): print(m["id"])' 2>/dev/null | sort -u)
  ((${#OU[@]})) || { echo "❌ No models parsed from the OU response (/tmp/ou_models.json may be malformed)."; exit 1; }
  echo; echo "OU AI Sandbox models (OU LiteLLM):"
  for i in "${!OU[@]}"; do printf "  %3d) %s\n" "$((i+1))" "${OU[$i]}"; done
  echo
  read -rp "Primary model number [default 1]: " p </dev/tty; p="${p:-1}"
  if ! [[ "${p}" =~ ^[0-9]+$ ]] || (( p < 1 || p > ${#OU[@]} )); then echo "Invalid choice."; exit 1; fi
  PRIMARY="${OU[$((p-1))]}"
  apply_model "litellm" "${PRIMARY}"
  exit 0
fi

# ---- OpenRouter branch (default) ------------------------------------------
if ! [[ "${choice}" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > N )); then
  echo "Invalid choice."; exit 1
fi
PRIMARY="${OR_IDS[$((choice-1))]}"
apply_model "openrouter" "${PRIMARY}"
