# Plan T-008: Per-Repo Git Identity Prompt & Wrong-Email Commit/Push Guard

Todo: `T-008`
Status: open
Independent: yes (can be built independently; coordinates cleanly with `T-007` `pre-push` and `T-002` `pulled.sh`)

## Problem

When a developer links both a personal email and an organization/work email to the same GitHub account, a single global `git config --global user.email` easily causes commits and pushes in an org repo to go out with the personal email (or vice versa). Right now:
- `BOOTSTRAP.md` and `install.sh` never ask which email a repo should use for commits and pushes.
- No local hook checks outgoing commits before `git commit` or `git push` against the repo's chosen email.
- `workspace.sh` / `doctor.sh` do not surface which `user.email` is active in each repo of a mixed workspace.

## Goal

Ask once per repo which email (and optional `user.name`) should be used for commits and pushes, store it strictly locally (never committed to shared configs), and block accidental commits or pushes made with the wrong email.

## Files to Change

- `templates/kit/identity.sh` (new, POSIX sh helper: inspect, prompt choices, set local `git config`, check commits)
- `templates/githooks/pre-commit` (call `identity.sh --check-staged` or `--check-current`)
- `templates/githooks/pre-push` (new or shared with `T-007`: verify outgoing commits `@{u}..HEAD` match repo email)
- `templates/kit/check.sh` (optional local-only identity check, skipped in `--ci`)
- `BOOTSTRAP.md` (add the git-email question during repo setup; record choice locally, not in committed `.agents/agent-kit.conf`)
- `WORKSPACE.md` / `templates/workspace/workspace.sh` (show active `EMAIL` or mismatch warning in `status` / `add`)
- `doctor.sh` (optional: show per-repo `user.email` if configured)
- `tests/run.sh` (add identity set/check/mismatch tests)

## Implementation Plan

1. **Keep the choice strictly local (never pushed):**
   - Never write a personal email into `.agents/agent-kit.conf` when `SHARE` is `agent` or `all` (teammates must not inherit your email).
   - Store the repo's chosen email in:
     1. `git config --local user.email "<email>"` (and optional `user.name`), and
     2. `$(git rev-parse --git-common-dir)/agent-kit/expected-email` (or `git config --local agent-kit.expectedEmail`) so the kit knows the choice was explicitly confirmed for this repo.
   - Maintain a small local list of your previously chosen emails in `${AGENT_KIT_STATE:-$HOME/.agent-kit}/identities` so new repos can offer your personal and org emails as numbered choices without re-typing.
2. **Ask during setup (`BOOTSTRAP.md` + `identity.sh`):**
   - Inspect `git config --local user.email`, `git config --global user.email`, recent commit emails in the repo, the `origin` remote URL (org/owner hint), and `~/.agent-kit/identities`.
   - Ask one choice question right after `REPO_KIND` (`personal` vs `team`):
     - Proposed answer first (e.g., matching org email for a `team` repo, or personal email for a `personal` repo),
     - Other known email(s) from `~/.agent-kit/identities` / global config,
     - Skip / keep current git config,
     - Type your own email.
   - Apply via `sh .agents/kit/identity.sh set "<email>" ["<name>"]`.
3. **Guard commits and pushes (`pre-commit`, `pre-push`, `PreToolUse`):**
   - On **`pre-commit`**: if `expected-email` is set for this repo and the effective commit email (`GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_EMAIL` / `git var GIT_AUTHOR_IDENT`) differs from `expected-email` (or if `git config --local user.email` is unset when global doesn't match), fail with the exact fix (`git config --local user.email "..."` or `sh .agents/kit/identity.sh set "..."`).
   - On **`pre-push`**: inspect outgoing commits (`git log --format='%H %ae %ce' @{u}..HEAD` or against remote refs) and block the push if any unpushed commit carries a mismatched email, printing the `git commit --amend --reset-author` / `rebase` fix.
   - In **`KIT_HOOKS=no` team repos**: warn in `install.sh` / `session-start.sh` if `expected-email` is not set yet or doesn't match `git config user.email`, and provide a one-line `identity.sh check` command.
4. **Coordinate with `pulled.sh` (`T-002`) and `workspace.sh` (`T-003`):**
   - `pulled.sh` can treat `~/.agent-kit/identities` (or `SELF_EMAILS`) + `expected-email` as your own commits when checking teammate pulls.
   - `workspace.sh status` can show the active `EMAIL` column or flag mismatches across mixed personal + org workspaces.

## Verification

- Add tests in `tests/run.sh`:
  - Setting `identity.sh set` updates local `git config user.email` and `~/.agent-kit/identities` without modifying tracked files.
  - `identity.sh check` passes when matching and fails with exact fix when `GIT_AUTHOR_EMAIL` or `git config user.email` mismatches.
  - `pre-push` check rejects an outgoing commit authored with the wrong email.
- Run `sh tests/run.sh` and `sh .agents/kit/check.sh`.
