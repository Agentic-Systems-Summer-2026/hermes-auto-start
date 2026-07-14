#!/usr/bin/env bash
# DEPRECATED: This repo has migrated from Hermes Agent to OpenCode.
# This script is kept as a backward-compatibility shim and simply delegates
# to start-opencode.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start-opencode.sh" "$@"
