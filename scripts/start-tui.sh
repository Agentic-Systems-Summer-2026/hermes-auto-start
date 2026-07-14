#!/usr/bin/env bash
# Backward-compatibility shim: delegates to start-opencode.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start-opencode.sh" "$@"
