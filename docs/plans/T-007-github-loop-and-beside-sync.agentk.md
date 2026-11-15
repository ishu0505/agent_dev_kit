# Plan T-007: Close GitHub / Actions Loop & Harden Team-Repo (`beside`) Resilience

Todo: `T-007`
Status: open
Independent: yes (scoped to CI workflow, `gh` helper/skill, `pre-push`, `overlay.sh`, `wire.sh`)

## Problem

1. **No `gh` CI / PR-review feedback loop:** Developers have to manually copy-paste failing GitHub Actions logs (`gh run view --log-failed`) and PR review comments into their agent session or task file.
2. **Minimal CI (`templates/ci/github-actions.yml`):** Only runs `check.sh --ci`. Does not optionally run `--run-commands`, warn when `INTERFACE_GLOBS` change without a `DECISIONS` or map update, or check/update the `explain-diff` PR section.
3. **Team-repo (`beside`) hook blackout (`KIT_HOOKS=no`):** In `install.sh:143-147`, when a team uses `.husky`, `lefthook`, `.pre-commit-config.yaml`, or `.githooks`, no kit git hooks are installed. Also `wire.sh` ignores team `.github/copilot-instructions.md` and `.claude/rules/`.
4. **No portable backup for `beside` / `SHARE="none"` docs:** Personal `AGENTS.agentk.md`, `DECISIONS.agentk.md`, `TODO.agentk.md`, and `learning_docs/` live only inside `.git/info/exclude` on one machine.

## Goal

Make GitHub / GitHub Actions an active part of the dev-in-the-loop workflow, protect `beside` repos even when `KIT_HOOKS=no`, and prevent losing local overlays across machines.

## Files to Change

- `templates/ci/github-actions.yml`
- `templates/kit/gh-loop.sh` (new, POSIX sh wrapping `gh` read-only queries)
- `templates/kit/overlay.sh` (new, POSIX sh export/import/sync for `beside`/`none` files)
- `templates/githooks/pre-push` (new)
- `templates/kit/wire.sh` (surface `.github/copilot-instructions.md` and `.claude/rules/` in `--plan`)
- `templates/skills/wrap-up/SKILL.md` or new `templates/skills/gh-sync/SKILL.md`
- `install.sh` (install `pre-push` when `KIT_HOOKS=yes`, expose `overlay.sh` / `gh-loop.sh`)
- `tests/run.sh`

## Implementation Plan

1. **Local `gh` feedback helper (`gh-loop.sh`):**
   - Read-only commands using `gh` (fail gracefully with clear install/auth message if `gh` is missing):
     - `gh-loop.sh ci [<branch|run-id>]`: fetch failed check names + trimmed `--log-failed` excerpt.
     - `gh-loop.sh comments [<pr>]`: fetch unresolved PR review comments (`path:line` + body).
     - `gh-loop.sh sync-task <task-name>`: append CI failures and PR comments into `.agents/work/<task>.agentk.md` under `## Open questions` / `## Plan` so the agent fixes them with full context and dev review.
2. **Expand `templates/ci/github-actions.yml`:**
   - Keep `check.sh --ci` fast and zero-setup by default.
   - Add clearly documented optional steps/jobs:
     - `--run-commands` / `VERIFY_CMD` execution after project setup.
     - PR interface guard: check `INTERFACE_GLOBS` changes against `DECISIONS` / map updates (warn or fail by repo flag).
     - Check whether the PR body has the `<!-- agent-kit:explain -->` section from `explain-diff`.
3. **Team-repo (`beside`) safety net (`pre-push` + `wire.sh`):**
   - Add `templates/githooks/pre-push` running `check.sh --quiet` when `KIT_HOOKS=yes`, plus a `gh-loop.sh pr-check` (or `pre-push` snippet) for `KIT_HOOKS=no` repos so developers can run `check.sh` + `wire.sh --check` before pushing.
   - Update `wire.sh --plan` to detect and report `.github/copilot-instructions.md` and `.claude/rules/` alongside `AGENTS.md`/`CLAUDE.md`.
4. **Personal overlay backup/restore (`overlay.sh`):**
   - `overlay.sh export [<dir>]` / `overlay.sh import [<dir>]` (defaulting to `${AGENT_KIT_STATE:-$HOME/.agent-kit}/overlays/<repo-slug>/` or a user-specified private git repo): copies all local kit docs (`*DOC_SUFFIX`, `.agents/agent-kit.conf`, `learning_docs/`, excluding ephemeral `.agents/work/` and `.agents/kit/`) so switching laptops, re-cloning, or spinning up a new worktree preserves all personal context.

## Verification

- Test `overlay.sh export` + `import` in a fresh clone in `tests/run.sh`.
- Test `gh-loop.sh` argument handling and missing-`gh` fallback in `tests/run.sh`.
- Validate `templates/ci/github-actions.yml` syntax and run `sh tests/run.sh` + `sh .agents/kit/check.sh`.
