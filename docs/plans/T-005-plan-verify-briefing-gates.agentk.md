# Plan T-005: Plan Gate, Verify Gate (`VERIFY_CMD`), and "Dev Briefing" in `wrap-up`

Todo: `T-005`
Status: open
Independent: yes (scoped to `task.*`, `check.sh`, `wrap-up`, `explain-diff`, `agent-kit.conf`)

## Problem

1. **No plan-approval gate:** `task.agentk.md` only tracks `Status: active | paused`. On multi-unit or cross-repo tasks, an agent can start editing files immediately before the developer signs off on the plan.
2. **No programmatic verify gate:** `check.sh` validates docs, not code tests/linters. `RUN_COMMANDS_MAPS` in `agent-kit.conf` is empty by default and `wrap-up` does not require the repo's check/test command to pass before marking a task done.
3. **Scattered comprehension view:** Blast radius (files touched, `Hidden links` / `LINKS` touched, maps updated, checks run, and diff walkthrough) is spread across `check.sh`, `wrap-up`, and `explain-diff`, rather than giving the developer one crisp "Dev Briefing" to keep up with agent speed.

## Goal

Add lightweight human-in-the-loop Plan and Verify gates and produce one clear Dev Briefing at task end / before PR.

## Files to Change

- `templates/kit/task.agentk.md`
- `templates/kit/task.sh`
- `templates/config/agent-kit.conf`
- `templates/kit/check.sh`
- `templates/docs/AGENTS.root.md`
- `templates/skills/wrap-up/SKILL.md`
- `templates/skills/explain-diff/SKILL.md`
- `tests/run.sh`

## Implementation Plan

1. **Plan gate in `task.agentk.md` and `task.sh`:**
   - Support `Status: planning | approved | active | paused` (with `task.sh new --plan <name>` creating `Status: planning` and `task.sh approve <name>` setting `Status: approved`).
   - Update `AGENTS.root.md` and `session-start.sh` / `pre-tool-guard` guidance: when an active task is `Status: planning`, present the `## Plan` and ask the user to approve before editing code files.
2. **Verify gate (`VERIFY_CMD` + `--run-commands`):**
   - Add optional `VERIFY_CMD=""` in `agent-kit.conf` (or read `## Check` commands when `RUN_COMMANDS_MAPS` is configured).
   - Add `sh .agents/kit/check.sh --verify` (or run `VERIFY_CMD` + `check.sh --run-commands`) and require `wrap-up` Step 1 to run it and report exact pass/fail output (never claiming "done" with unverified or failing checks).
3. **Single "Dev Briefing" in `wrap-up` Step 7:**
   - Replace scattered end-of-task summaries with a crisp Dev Briefing block:
     1. **Blast radius:** files/units changed + any `Hidden links` or workspace `LINKS` touched.
     2. **Verification:** exact commands run and pass/fail status (or explicitly "not run").
     3. **Docs & decisions:** maps/learning docs/decisions updated or waiting.
     4. **Comprehension offer:** if branch diff exceeds a configurable threshold (e.g., `DIFF_EXPLAIN_LINES=300` or multi-unit), automatically offer `explain-d-in` (interactive page) or `explain-d-ez` alongside `explain-diff`.

## Verification

- Add tests in `tests/run.sh` for `task.sh new --plan`, `task.sh approve`, and `check.sh` / `VERIFY_CMD` pass/fail behavior.
- Run `sh tests/run.sh` and `sh .agents/kit/check.sh`.
