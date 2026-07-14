#!/usr/bin/env bash
# Sourced by the other scripts. Makes `opencode` discoverable in non-interactive
# VS Code *task* shells, which don't load ~/.bashrc.
# The official OpenCode installer places the binary in $HOME/.opencode/bin or
# $HOME/.local/bin (when XDG_BIN_DIR is set). We search all common locations.
for _d in \
  "${HOME}/.local/bin" \
  "${HOME}/bin" \
  "${HOME}/.opencode/bin" \
  "${HOME}/.cargo/bin"
do
  if [ -d "${_d}" ]; then
    case ":${PATH}:" in
      *":${_d}:"*) : ;;
      *) PATH="${_d}:${PATH}" ;;
    esac
  fi
done
# Last resort: if opencode still isn't resolvable, search for it on disk.
if ! command -v opencode >/dev/null 2>&1; then
  _h="$(find "${HOME}/.opencode" "${HOME}/.local" -maxdepth 6 -name opencode -type f 2>/dev/null | head -n1 || true)"
  if [ -n "${_h:-}" ]; then
    case ":${PATH}:" in *":$(dirname "${_h}"):"*) : ;; *) PATH="$(dirname "${_h}"):${PATH}" ;; esac
  fi
  unset _h
fi
export PATH
unset _d
