#!/usr/bin/env bash
# Sourced by the other scripts. Makes `hermes` discoverable in non-interactive
# VS Code *task* shells, which don't load ~/.bashrc.
# The official Hermes installer places the binary at ~/.local/bin/hermes
# (symlinked from the managed venv). We also search ~/.hermes/bin and other
# common locations as a safety net.
for _d in \
  "${HOME}/.local/bin" \
  "${HOME}/.hermes/bin" \
  "${HOME}/.cargo/bin"
do
  if [ -d "${_d}" ]; then
    case ":${PATH}:" in
      *":${_d}:"*) : ;;
      *) PATH="${_d}:${PATH}" ;;
    esac
  fi
done
# Last resort: if hermes still isn't resolvable, search for it on disk.
if ! command -v hermes >/dev/null 2>&1; then
  _h="$(find "${HOME}/.hermes" "${HOME}/.local" "${HOME}/.cargo" -maxdepth 6 -name hermes -type f 2>/dev/null | head -n1 || true)"
  if [ -n "${_h:-}" ]; then
    case ":${PATH}:" in *":$(dirname "${_h}"):"*) : ;; *) PATH="$(dirname "${_h}"):${PATH}" ;; esac
  fi
  unset _h
fi
export PATH
unset _d
