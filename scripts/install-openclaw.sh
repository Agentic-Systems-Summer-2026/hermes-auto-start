#!/usr/bin/env bash
# DEPRECATED: This repo has migrated from OpenClaw to Hermes Agent.
# This script is kept as a backward-compatibility shim and simply delegates
# to install-hermes.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-hermes.sh" "$@"
