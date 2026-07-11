#!/usr/bin/env bash
# Backward-compatibility shim: this script previously started the OpenClaw
# gateway. Hermes Agent does not use a port-based gateway for CLI/TUI use.
# This script simply delegates to start-hermes.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start-hermes.sh" "$@"
