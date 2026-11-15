# Plan: Harden `agent_dev_kit` for Dev Control, Multi-Repo Workspaces, and Code Quality

## Goal

Improve `agent_dev_kit` (`0.15.1` -> `0.16.0`) so developers stay in complete control of code quality and agent velocity across private repos, `beside` team repos, overlapping multi-repo worktree workspaces, and Git/GitHub workflows—without losing the kit's plain-Markdown + POSIX-sh simplicity.

## First milestone

The remaining tracks (`T-003` through `T-008`; `T-001` and `T-002` shipped in 0.15.1) in `TODO.agentk.md` pass `sh tests/run.sh`, `python3 guide/build.py`, and `sh .agents/kit/check.sh`. Out of scope: background daemons, SQLite/vector databases, or multi-agent swarm orchestrators.

## Planned tracks (independent, agent-ready)

Each track maps 1:1 to a `TODO.agentk.md` item and a self-contained plan file so an individual agent can implement one track in isolation.

| Todo | Track | Plan file | Primary files |
|---|---|---|---|
| `T-003` | Workspace tasks, branch/dirty status, active-repo scoping, and all-agent hooks | `docs/plans/T-003-workspace-tasks-and-hooks.agentk.md` | `templates/workspace/workspace.sh`, `ws-hook.sh`, `WORKSPACE.md`, hook JSONs |
| `T-004` | `PreToolUse` guardrails, `PreCompact` recovery, optional `PostToolUse`, and quiet banner | `docs/plans/T-004-lifecycle-hooks-and-banner.agentk.md` | `templates/kit/pre-tool-guard.sh`, `pre-compact.sh`, `sessions.sh`, hook JSONs |
| `T-005` | Plan-approval gate, `VERIFY_CMD` verify gate, and single "Dev Briefing" in `wrap-up` | `docs/plans/T-005-plan-verify-briefing-gates.agentk.md` | `templates/kit/task.sh`, `task.agentk.md`, `check.sh`, `templates/skills/wrap-up/SKILL.md` |
| `T-006` | Task/path-scoped Context DI (ICM-style routing & `.claude/rules/` generation) | `docs/plans/T-006-context-di-routing.agentk.md` | `templates/kit/wire.sh`, `check.sh`, `install.sh`, `templates/config/agent-kit.conf` |
| `T-007` | GitHub / Actions loop (`gh-loop.sh`), CI upgrades, `pre-push`, and `beside` overlay backup | `docs/plans/T-007-github-loop-and-beside-sync.agentk.md` | `templates/ci/github-actions.yml`, `templates/kit/gh-loop.sh`, `overlay.sh`, `wire.sh` |
| `T-008` | Per-repo git email prompt (personal vs org) and wrong-email commit/push guard | `docs/plans/T-008-per-repo-git-identity.agentk.md` | `templates/kit/identity.sh`, `BOOTSTRAP.md`, `templates/githooks/pre-commit`, `pre-push` |

## Rules for parallel agents

- Read `AGENTS.md`, the assigned `T-NNN` item in `TODO.agentk.md`, and its `docs/plans/T-NNN-*.agentk.md` before editing.
- Keep shared release files (`VERSION`, `CHANGELOG.md`, `README.md`, `guide/build.py`) out of individual feature commits until integration, or rebase cleanly before running `sh tests/run.sh` and `python3 guide/build.py`.
- Any new file added to a `beside` repo must be added to both `install.sh` (beside exclude list) and `templates/kit/check.sh` (`kit_local_paths`).

