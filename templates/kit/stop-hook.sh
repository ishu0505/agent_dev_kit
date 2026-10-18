#!/bin/sh
# Stop hook entry point for every agent. Finds the repo from wherever the
# agent runs, and lets the stop through when python3 is missing.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
exec python3 "$ROOT/.agents/kit/docs_reminder.py"
