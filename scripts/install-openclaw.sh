#!/usr/bin/env bash
# DEPRECATED: This repo has migrated from OpenClaw to Hermes Agent to OpenCode.
# This script is kept as a backward-compatibility shim and simply delegates
# to install-opencode.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-opencode.sh" "$@"
