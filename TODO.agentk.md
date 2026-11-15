# Todo

Next ID: 9

<!-- Ideas and follow-ups for a later session, one block per item. The todo
skill writes this file with sh .agents/kit/todo.sh (add, list, show, set,
done). Category is one of TODO_CATEGORIES in .agents/agent-kit.conf; Status
is open or doing. Refs are context for the work, not its limits. A done item
is deleted; git history keeps it. -->

## T-003: Add workspace-level task files, branch/dirty status, active-repo scoping, and all-agent hooks

Category: task
Status: open
Added: 2026-11-13
From: review
Refs: `PLAN.agentk.md`, `docs/plans/T-003-workspace-tasks-and-hooks.agentk.md`, `templates/workspace/workspace.sh`, `templates/workspace/ws-hook.sh`, `templates/workspace/WORKSPACE.md`, `templates/workspace/workspace.conf`, `WORKSPACE.md`, `tests/run.sh`

Add `.agent-workspace/work/` tasks for cross-repo work, branch/dirty/ahead-behind info in `workspace.sh status`, `branch` and `remove` commands, `ACTIVE_REPOS` scoping in `ws-hook.sh`, and workspace hook configs for Antigravity, Gemini, and Cursor.

## T-004: Add PreToolUse guardrails, PreCompact recovery, optional PostToolUse, and quiet SESSION_BANNER default

Category: task
Status: open
Added: 2026-11-13
From: review
Refs: `PLAN.agentk.md`, `docs/plans/T-004-lifecycle-hooks-and-banner.agentk.md`, `templates/config/claude-settings.json`, `templates/config/codex-hooks.json`, `templates/config/agy-hooks.json`, `templates/config/agent-kit.conf`, `templates/kit/sessions.sh`, `README.md`, `tests/run.sh`

Block edits to team agent files (`beside`), non-kit Markdown, and secrets before tool calls (`PreToolUse`) instead of only warning at `Stop`. Wire `PreCompact` as promised in `README.md`, add opt-in `POST_EDIT_CMD`, and default `SESSION_BANNER` to `first` instead of per-turn LLM self-reporting.

## T-005: Add plan-approval gate, VERIFY_CMD verify gate, and single Dev Briefing in wrap-up

Category: task
Status: open
Added: 2026-11-13
From: review
Refs: `PLAN.agentk.md`, `docs/plans/T-005-plan-verify-briefing-gates.agentk.md`, `templates/kit/task.agentk.md`, `templates/kit/task.sh`, `templates/config/agent-kit.conf`, `templates/kit/check.sh`, `templates/docs/AGENTS.root.md`, `templates/skills/wrap-up/SKILL.md`, `templates/skills/explain-diff/SKILL.md`

Add `Status: planning | approved` to task files so multi-unit edits wait for developer sign-off, run `VERIFY_CMD` / `check.sh --run-commands` in `wrap-up`, and combine blast radius, checks, docs, and diff explanation offers into one concise Dev Briefing.

## T-006: Add task and path-scoped Context DI routing and .claude/rules generation

Category: task
Status: open
Added: 2026-11-13
From: review
Refs: `PLAN.agentk.md`, `docs/plans/T-006-context-di-routing.agentk.md`, `templates/config/agent-kit.conf`, `templates/kit/wire.sh`, `templates/kit/check.sh`, `templates/docs/AGENTS.root.md`, `install.sh`, `tests/run.sh`

Adopt ICM-style Context Dependency Injection without rigid numbered stage folders: route small rule files (`*.agentk.md`) by path glob or task type, generate `.claude/rules/agent-kit-*.md` (`paths:` frontmatter) and `.cursor/rules/*.mdc` via `wire.sh`, and keep them out of git in `beside` mode.

## T-007: Close GitHub Actions and gh review loop, add pre-push, and support beside overlay sync

Category: task
Status: open
Added: 2026-11-13
From: review
Refs: `PLAN.agentk.md`, `docs/plans/T-007-github-loop-and-beside-sync.agentk.md`, `templates/ci/github-actions.yml`, `templates/kit/wire.sh`, `templates/githooks/pre-commit`, `install.sh`, `tests/run.sh`

Add a `gh` helper to pull failed CI logs and PR review comments into the active task file, expand `github-actions.yml` with optional verify/`INTERFACE_GLOBS`/`explain-diff` steps, add `pre-push` + `.claude/rules`/Copilot detection for `beside` mode, and add portable `overlay.sh` backup/restore.

## T-008: Ask per-repo git email during setup (personal vs org) and guard commits and pushes against wrong email

Category: task
Status: open
Added: 2026-11-14
From: user idea
Refs: `PLAN.agentk.md`, `docs/plans/T-008-per-repo-git-identity.agentk.md`, `BOOTSTRAP.md`, `templates/githooks/pre-commit`, `templates/kit/check.sh`, `templates/workspace/workspace.sh`, `doctor.sh`, `tests/run.sh`

Ask once per repo which email (`user.email`) commits and pushes should use (offering known personal/org emails cached locally in `~/.agent-kit/identities`), set `git config --local user.email` without committing personal info, and block commits/pushes made with a mismatched email.
