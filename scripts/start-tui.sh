#!/usr/bin/env bash
# Backward-compatibility shim: this script previously started the OpenClaw TUI
# after waiting for the gateway. Hermes Agent runs as a single process —
# there is no separate gateway to wait for.
# This script simply delegates to start-hermes.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start-hermes.sh" "$@"
