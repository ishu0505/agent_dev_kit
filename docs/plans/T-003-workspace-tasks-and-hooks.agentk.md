# Plan T-003: Workspace Tasks, Branch/Dirty Visibility, Repo Scoping, and Agent Hooks

Todo: `T-003`
Status: open
Independent: yes (scoped to `templates/workspace/` and workspace docs/tests)

## Problem

Multi-repo workspaces (`templates/workspace/`) currently lack key controls needed when managing overlapping or mixed workspaces (team + private + unconnected repos):
1. **No workspace-level task file:** `task.sh` only exists inside individual repos (`.agents/work/`). Cross-repo tasks (e.g., backend + frontend contract work) have no `.agent-workspace/work/<task>.agentk.md`.
2. **Thin git visibility & lifecycle:** `workspace.sh status` prints kit/queue/pulled/stale counts, but not current branch, dirty files, or ahead/behind remote. `workspace.sh add --worktree` leaves detached HEAD with no `ws branch` or clean `ws remove`.
3. **No active-repo scoping:** `ws-hook.sh` fires `session-start.sh` and `docs_reminder.py` for every `kit` repo in the folder, even if a task only touches 2 out of 10 repos.
4. **Missing workspace hooks for Antigravity, Gemini, and Cursor:** `templates/workspace/` only ships `claude-settings.json` and `codex-hooks.json`.

## Goal

Give multi-repo workspaces full task tracking, per-repo git visibility, active-repo scoping, and consistent hook wiring across all supported agents.

## Files to Change

- `templates/workspace/workspace.sh`
- `templates/workspace/ws-hook.sh`
- `templates/workspace/workspace.conf`
- `templates/workspace/WORKSPACE.md`
- `templates/workspace/agy-hooks.json` (new)
- `templates/workspace/gemini-settings.json` (new)
- `templates/workspace/cursor-rule.mdc` (new, installed to `.cursor/rules/agent-kit-workspace.mdc`)
- `WORKSPACE.md` (setup guide updates)
- `tests/run.sh` (add workspace task, status, and hook tests)

## Implementation Plan

1. **Workspace-level tasks (`.agent-workspace/work/`):**
   - Add `workspace.sh task new|list|path|close <name>` (reusing the same simple Markdown structure as `templates/kit/task.agentk.md`, adding a `Repos:` header listing involved repos and contracts).
   - Update `ws-hook.sh session-start` to list open `.agent-workspace/work/` tasks once.
2. **Upgrade `workspace.sh status` & add `branch` / `remove`:**
   - Extend `cmd_status` to show `BRANCH`, `DIRTY` (modified/untracked count), and `AHEAD/BEHIND` (when upstream exists) alongside `KIT`, `QUEUE`, `PULLED`, `STALE`.
   - Add `workspace.sh branch <task-branch> [--repos ...]` to create/switch coordinated branches across selected repos (never touching excluded repos).
   - Add `workspace.sh remove <dir>` to cleanly prune a `--worktree` checkout after checking for uncommitted changes.
3. **Active-repo scoping:**
   - Add `ACTIVE_REPOS=""` (empty = all) in `workspace.conf` (and `--repos` flag or task `Repos:` override).
   - Update `ws-hook.sh` to run `session-start.sh` only for active repos when `ACTIVE_REPOS` is set, keeping the workspace map aware of all repos.
4. **Add Antigravity, Gemini, and Cursor workspace configs:**
   - Add `agy-hooks.json` (installed to `.agents/hooks.json`), `gemini-settings.json` (`.gemini/settings.json`), and a workspace Cursor rule (`.cursor/rules/agent-kit-workspace.mdc`) inside `workspace.sh init`, matching `claude-settings.json` and `codex-hooks.json`.

## Verification

- Add tests in `tests/run.sh` for `workspace.sh task`, `workspace.sh status` dirty/branch output, `ACTIVE_REPOS` filtering in `ws-hook.sh`, and `workspace.sh init` hook generation.
- Run `sh tests/run.sh` and `sh .agents/kit/check.sh`.
