# Plan T-006: Task & Path-Scoped Context DI (ICM-Style Routing & `.claude/rules/`)

Todo: `T-006`
Status: open
Independent: yes (scoped to context routing config, `wire.sh`, `install.sh`, `AGENTS.root.md`)

## Problem

Inspired by Jake Van Clief's Interpretable Context Methodology (ICM / `Content-Agent-Routing-Promptbase`), loading only the exact rules needed for a micro-task keeps context small and prevents rule bleed. Right now, `agent_dev_kit`:
- Only routes context by **folder hierarchy** (`AGENTS.md` on the path to a folder).
- Has no **task-type or path-glob routing** (e.g., "editing SQL migrations -> load DB invariants; writing tests -> load test fixture conventions; reviewing a PR -> load security checklist").
- Does not generate native `.claude/rules/*.md` files with `paths:` YAML frontmatter or glob-scoped `.cursor/rules/*.mdc` files.

## Goal

Add optional path/task-scoped Context Dependency Injection (DI) without forcing rigid numbered stage folders (`01-/` `02-/`) onto normal software repos.

## Files to Change

- `templates/config/agent-kit.conf`
- `templates/kit/routes.sh` (new, POSIX sh) or subcommand in `wire.sh`
- `templates/kit/wire.sh`
- `templates/kit/check.sh` (validate route paths and `beside` local paths)
- `templates/docs/AGENTS.root.md`
- `install.sh` (add `.claude/rules/agent-kit-*.md` to `beside` exclude list)
- `tests/run.sh`

## Implementation Plan

1. **Define a tiny plain-text route config (`.agents/routes.agentk.md` or `ROUTES` in `agent-kit.conf`):**
   - Each entry maps a path glob or task type to a short rule file (`*.agentk.md`), keeping each injected slice tiny (e.g., under 40 lines):
     - Example: `migrations/** -> docs/rules/db-migrations.agentk.md`
     - Example: `tests/** -> docs/rules/testing.agentk.md`
2. **Generate native scoped rules via `wire.sh`:**
   - For **Claude Code**: write `.claude/rules/agent-kit-<name>.md` with `paths:` YAML frontmatter so Claude loads each rule *only* when touching matching files.
   - For **Cursor**: write `.cursor/rules/agent-kit-<name>.mdc` with `globs:` frontmatter.
   - For **Codex / Antigravity / Gemini**: list the compact `If touching <glob>, read <rule>` table in the root map (`AGENTS.md` / `AGENTS.agentk.md`) or inject matching routes in a prompt hook when changed/mentioned paths match.
3. **Keep `MAPS="beside"` & `SHARE="none"` clean:**
   - Ensure any generated `.claude/rules/agent-kit-*.md` and `.cursor/rules/agent-kit-*.mdc` are listed in `install.sh`'s `.git/info/exclude` rules and `check.sh`'s `kit_local_paths` so team repos stay untouched.
4. **Validate routes in `check.sh`:**
   - Fail if a route points to a missing rule file or exceeds a concise line cap (e.g., 40 lines), preventing bloated context injection.

## Verification

- Add tests in `tests/run.sh` verifying `wire.sh` generates valid `.claude/rules/agent-kit-*.md` with `paths:` frontmatter, cleans them up on `--remove`, keeps them ignored in `beside` mode, and fails `check.sh` on broken route targets.
- Run `sh tests/run.sh` and `sh .agents/kit/check.sh`.
