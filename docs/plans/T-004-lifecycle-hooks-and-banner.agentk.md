# Plan T-004: PreToolUse Guardrails, PreCompact Recovery, PostToolUse & Quiet Banner

Todo: `T-004`
Status: open
Independent: yes (scoped to hook configs and hook scripts)

## Problem

1. **Reactive warnings only:** `docs_reminder.py` only warns at `Stop` (after the turn finishes) if an agent edited team `AGENTS.md`/`CLAUDE.md` in `MAPS="beside"`, edited repo-owned Markdown outside `.agentk.md`, or made mistakes in the wrong repo.
2. **Missing `PreCompact` hook:** `README.md:38` states that the coding standard is loaded "again after compaction in Claude and Codex", but `templates/config/claude-settings.json` and `templates/config/codex-hooks.json` do not wire `PreCompact` (or `SessionStart` compact matcher).
3. **No optional `PostToolUse` fast feedback:** No hook runs a fast per-file formatter/linter right after file edits.
4. **Noisy 0.15.0 `SESSION_BANNER="every"` default:** `sessions.sh:66-68` prompts the LLM on every turn to print `agent-kit used: maps ... · tools ...`, adding recurring token overhead and relying on unverified LLM self-reports.

## Goal

Put hard deterministic guardrails *before* tool calls, preserve task/standard state across context compaction, and cut per-turn prompt noise.

## Files to Change

- `templates/kit/pre-tool-guard.sh` (new, POSIX sh)
- `templates/kit/pre-compact.sh` (new, POSIX sh)
- `templates/kit/post-tool-check.sh` (new, POSIX sh, opt-in via config)
- `templates/kit/sessions.sh`
- `templates/kit/session-start.sh`
- `templates/config/claude-settings.json`
- `templates/config/codex-hooks.json`
- `templates/config/agy-hooks.json`
- `templates/config/agent-kit.conf`
- `README.md`
- `tests/run.sh`

## Implementation Plan

1. **Deterministic `PreToolUse` guardrail (`pre-tool-guard.sh`):**
   - Parse tool input JSON (using standard POSIX tools or Python 3.9+ fallback like `stop-hook.sh`) for file-write/edit tools and shell/bash tools.
   - Block (exit 2 / deny JSON) when:
     - `MAPS="beside"` and target path is a tracked team file (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude/settings.json`, `.github/workflows/`).
     - Target is a non-kit `.md` file (`README.md`, `docs/*.md`, etc.) unless an explicit opt-in marker/env (`AGENT_KIT_ALLOW_REPO_MD=1` from `repo-md-sync`) is set.
     - Target matches secret patterns (`.env`, `.env.*` excluding `*.env.example`, `*.pem`, `*.key`).
     - In a workspace, a shell `git commit` or `git push` targets a repo different from the active task's scope or pushes directly to `main`/`master` without confirmation.
2. **Implement `PreCompact` / post-compaction recovery (`pre-compact.sh`):**
   - Wire `PreCompact` (and `SessionStart` compact matcher where supported) in `claude-settings.json` and `codex-hooks.json`.
   - Re-inject: `coding-standard.agentk.md` (if enabled), the active `.agents/work/*.agentk.md` file path + `Next:` line, and `beside` map rules.
3. **Optional `PostToolUse` hook (`post-tool-check.sh`):**
   - Add `POST_EDIT_CMD=""` to `agent-kit.conf`. When non-empty and a code file is edited, run the fast check (e.g., `ruff check`, `tsc --noEmit`, `sh -n`) and feed failures back immediately.
4. **Fix noisy per-turn banner (`sessions.sh` & `agent-kit.conf`):**
   - Default `SESSION_BANNER="first"` (keep `"every"` as an explicit opt-in) and stop asking the LLM to count its own tool calls; optionally compute real files touched/read from `transcript_path` or git status at `Stop` instead.

## Verification

- Test `pre-tool-guard.sh` directly in `tests/run.sh` with mock JSON payloads (verify block on team `CLAUDE.md` in `beside` mode, block on `README.md`, allow `.agentk.md`, block `.env`).
- Test `pre-compact.sh` output includes active task and coding standard.
- Run `sh tests/run.sh` and `sh .agents/kit/check.sh`.
