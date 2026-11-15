# Plan T-010: Headless Unattended Docs Sync Runner

Todo: `T-010`
Status: open
Independent: yes

> Already shipped in 0.16.0 (T-009): the read-only scan, as
> `doctor.sh --stale [folder]`. Use it as the runner's pre-filter (step 2)
> instead of writing a new scan. T-004's PreToolUse hook (`pre-edit.sh`)
> already exists to extend with the write-docs-only rule (step 5). T-003
> was dropped.

## Context & Why We Need This

Right now, `agent_dev_kit` detects and updates stale documentation one repo at a time inside interactive chat sessions:
- **Outside a workspace**, `doctor.sh` checks only kit versions, repo level (`repo` vs `repo, in a workspace`), and per-agent wiring/last-session timestamps. It does **not** report stale maps, stale `learning_docs/`, or missing/stale `interactive_l_docs/` across repos in a folder.
- **Updating docs requires interactive confirmations:** `learning-docs` asks the user to approve its file plan before writing (`templates/skills/learning-docs/SKILL.md`), and `interactive-docs` asks before fixing `(learning doc stale)` items or deleting orphans (`templates/skills/interactive-docs/SKILL.md`).
- **No unattended overnight runner:** There is no single terminal command that works identically on a **single code repo**, a **multi-repo workspace**, or an **arbitrary parent folder of repos**, skips clean repos at zero token cost, and runs `claude`, `codex`, or `agy` headlessly with **zero permission popups** so docs and interactive HTML pages stay up to date while the developer sleeps.

## Goal

Provide:
1. A fast, read-only staleness scan across any target (single repo, workspace, or parent directory of repos) that prints which repos have stale docs, stale learning docs, or missing/stale interactive pages.
2. Explicit `--force` mode in `docs-sync`, `learning-docs`, and `interactive-docs` (e.g., `docs-sync check --force`, `interactive-docs sync --force`, `learning-docs stale --force`) plus per-agent permission allowlists/flags so **reading code, learning docs, and interactive docs anywhere in the repo, workspace, or configured `LEARNING_DIR`** and **writing inside the configured `LEARNING_DIR/` (`LEARNING_DIR/interactive_l_docs/`)** (or kit `*.agentk.md` docs in `docs-sync fix`) never stop for permission popups—while **source code edits and `git commit` remain forbidden**.
3. A single terminal command (e.g. `sh <kit>/sync-docs.sh --agent claude|codex|agy [options] [target]`) that skips up-to-date repos and runs the chosen CLI agent **non-interactively and without popups** overnight.

## Files to Change

- `sync-docs.sh` (new, POSIX `sh` script at kit root: target discovery, deterministic staleness pre-filter, headless per-repo runner for `claude` / `codex` / `agy`, strict read-everywhere / write-docs-only permissions & post-run diff guard, and summary log)
- `doctor.sh` (add `--stale` or call shared scan logic to surface stale docs, stale learning docs, and stale interactive pages alongside kit status)
- `templates/config/claude-settings.json` (optional/wired read-only kit commands + `LEARNING_DIR/` write allowlist or generated `--settings` for unattended runs, coordinating with `T-004` `PreToolUse` guardrails)
- `templates/skills/docs-sync/SKILL.md` (add `--force` mode for `check --force` and `fix --force`: no pauses, read code across repo/workspace, write only kit `*.agentk.md` docs in `fix` mode and nothing in `check` mode, never edit code or commit)
- `templates/skills/learning-docs/SKILL.md` (add `--force` / unattended mode: skip plan-approval pause, read code across repo/workspace, write **only** inside `LEARNING_DIR/`, never edit code or commit)
- `templates/skills/interactive-docs/SKILL.md` (add `--force` / unattended mode for `sync --force`: skip confirmation pauses, read code/docs across repo/workspace, write **only** inside `LEARNING_DIR/interactive_l_docs/`, never delete orphans silently, never edit code or commit)
- `global-skills/agent-kit/SKILL.md` (document `doctor --stale` and `sync-docs.sh` in the global skill reference)
- `AGENTS.md` and `README.md` (add `sync-docs.sh` to the map and CLI usage docs)
- `tests/run.sh` (test target discovery, clean-repo skip, `--dry-run`, and mock-CLI invocation for `claude`, `codex`, and `agy`)

## Implementation Plan

1. **Unified target discovery (single repo, workspace, or parent folder):**
   - Given `[target]` (default `.`):
     - If `target` is inside a git repo (`git -C "$target" rev-parse --show-toplevel` succeeds, and it is not a `--meta` workspace root whose subfolders are separate repos), scan that single repo.
     - If `target` is a workspace (`.agent-workspace/workspace.conf` exists) or any plain parent directory holding repos, scan up to two levels deep (`-mindepth 2 -maxdepth 3 -name .git`, matching `doctor.sh` and `workspace.sh`).
   - Classify each folder:
     - Not a git repo -> ignore (or note in `--verbose`).
     - Git repo without `.agents/kit/VERSION` -> report `no kit` and skip.
     - Git repo with `.git/agent-kit/declined` -> report `declined` and skip.
     - Git repo with `.agents/kit/VERSION` -> eligible for staleness check.

2. **Fast deterministic staleness pre-check (zero LLM tokens):**
   - For each kit-enabled repo, run pure-shell checks first:
     - `sh .agents/kit/stale.sh` (and `sh .agents/kit/pulled.sh count` if present) to detect stale maps, kit detail docs, decisions, and learning docs.
     - `sh .agents/skills/interactive-docs/status.sh` (when `LEARNING_DIR` exists) to detect `missing`, `stale`, `orphan`, and `(learning doc stale)` HTML pages.
   - With `--check` / `--dry-run` (or `doctor.sh --stale`), print a clean per-repo summary table and exit without calling any LLM.
   - In run mode, **skip every repo with zero stale items** so overnight runs spend tokens only on repos that actually changed.

3. **One-command headless runner (`sync-docs.sh`) with agent selection & zero permission popups:**
   - CLI interface:
     - `--agent <claude|codex|agy>` (required unless `AGENT_KIT_SYNC_AGENT` is set; optionally `--model <name>` passed through to the CLI).
     - `--scope <learning|docs|all>` (default `learning`: refresh stale `learning_docs/` + `interactive-docs sync` only; `docs`: `docs-sync fix`; `all`: `docs-sync fix` + `learning-docs stale` + `interactive-docs sync`).
     - `--check` / `--dry-run` (print what would run and exit 0).
     - `--log-dir <dir>` (default `${AGENT_KIT_STATE:-$HOME/.agent-kit}/sync-logs/<timestamp>/`, writing one log per repo plus a final summary).
     - `--timeout <seconds>` (per-repo wall-clock guard so one stuck repo does not stall the whole overnight batch).
   - **Per-CLI non-interactive & scoped permissionless flags (read repo/workspace/learning & interactive docs everywhere, write configured docs only, no code edits or commits):**
     - Resolve `LEARNING_DIR` dynamically from `.agents/agent-kit.conf` (default `learning_docs`) instead of hardcoding `learning_docs/`. Note that `LEARNING_DIR` and `LEARNING_DIR/interactive_l_docs/` are often gitignored/excluded (when `SHARE` is `agent` or `none`) or customized to another path—explicitly allow both **reads and writes** there regardless of `.gitignore`/`.git/info/exclude`.
     - Pass `--add-dir` (supported by `agy --add-dir`, `codex exec --add-dir`, and Claude's `--add-dir`) for:
       1. the **workspace root** (when `.agent-workspace/workspace.conf` exists in `..` or `../..`), and
       2. the resolved **`LEARNING_DIR` path** if it points outside the repo root,
       so reading cross-repo code, `WORKSPACE.agentk.md`, learning docs, and interactive HTML pages never triggers permission prompts.
     - **`agy`** (observed in `agy --help`): run in repo root with `agy --print --mode accept-edits` (or `--dangerously-skip-permissions` when running kit read-only bash commands like `stale.sh`/`status.sh`) + temporary `--settings <json>` + `--add-dir <workspace/external LEARNING_DIR>` + optional `--model`.
     - **`codex`** (observed in `codex exec --help`): run `codex exec -C "$repo" -s workspace-write --approve-for-me` (with `--add-dir <workspace/external LEARNING_DIR>`, `-m <model>`, `-o <summary-file>`) or `--dangerously-bypass-approvals-and-sandbox` if `--unsafe` is requested.
     - **`claude`**: run `claude -p` with `--permission-mode acceptEdits`, `--add-dir <workspace/external LEARNING_DIR>`, and `--allowedTools` scoped strictly to read-only tools (`Read`, `Glob`, `Grep` across repo, workspace, `LEARNING_DIR`, and `LEARNING_DIR/interactive_l_docs`), kit read-only shell commands (`sh .agents/kit/stale.sh*`, `sh .agents/kit/check.sh*`, `sh .agents/kit/pulled.sh*`, `sh .agents/skills/interactive-docs/status.sh*`, `git status*`, `git diff*`, `git log*`), and doc-path writes (`<LEARNING_DIR>/**`, plus `*.agentk.md` / `AGENTS.md` only when `--scope docs|all`)—never allowing `git commit` or source-code edits (verify exact Claude flags against `claude --help` during implementation).
   - Pass a strict unattended prompt telling the agent:
     - Treat `--force` as active: do not ask confirmation questions.
     - Read code, `LEARNING_DIR/`, and `LEARNING_DIR/interactive_l_docs/` freely anywhere in the repo (and workspace, if present).
     - Write **only** inside `<LEARNING_DIR>/` (for `learning-docs --force` / `interactive-docs sync --force`) or kit-owned docs (`*.agentk.md` / `AGENTS.md`, when `--scope docs|all`). **Never** edit source code, non-kit `README.md` files, or run `git commit` / `git push`.

4. **Skill updates (`--force` mode) & interactive chat permission rules:**
   - Update `templates/skills/learning-docs/SKILL.md`, `templates/skills/interactive-docs/SKILL.md`, and `templates/skills/docs-sync/SKILL.md` to recognize `--force` (both in interactive chat and via `sync-docs.sh`):
     - `docs-sync check --force`: strictly read-only across repo/workspace, `LEARNING_DIR/`, and `LEARNING_DIR/interactive_l_docs/`; zero prompts, zero edits, zero commits; outputs the drift tables.
     - `docs-sync fix --force`: skips approval prompts, reads repo/workspace/learning & interactive docs freely, writes only kit-owned docs (`*.agentk.md`, `AGENTS.md`, `<LEARNING_DIR>/`), never edits code or commits.
     - `learning-docs [stale|all] --force` and `interactive-docs sync --force`: skip plan/confirmation pauses, read code/learning/interactive docs freely across repo/workspace/configured `LEARNING_DIR`, write **only** inside configured `<LEARNING_DIR>/` (and `<LEARNING_DIR>/interactive_l_docs/`), report orphans without deleting, never edit code or commit, and finish with `sh .agents/kit/check.sh` + `sh .agents/skills/interactive-docs/status.sh`.
   - **Why chat-session permission rules also matter:** A `SKILL.md` prompt alone cannot disable host CLI approval dialogs if the user started an interactive session in default "ask" mode. Therefore, wire safe pre-approved read patterns (repo/workspace reads + `LEARNING_DIR/` & `interactive_l_docs/` reads + read-only kit status commands + `LEARNING_DIR/` writes) into `templates/config/claude-settings.json` (or `T-004`'s `PreToolUse` auto-allow/guardrail script for `claude` / `codex` / `agy` where supported) so even in interactive chat, `docs-sync check --force` and `interactive-docs sync --force` don't stop every 2 seconds asking to read files.

5. **Post-run & hook safety guardrails (important when running permissionless overnight):**
   - Before invoking the agent in a repo, snapshot `git status --porcelain`.
   - While running in `learning` scope (`learning-docs --force` / `interactive-docs sync --force`), any write outside `LEARNING_DIR/` is disallowed (enforced in `PreToolUse` when `T-004` is active, and verified post-run via `git status --porcelain`).
   - After the agent exits, verify via `git status --porcelain` that no source-code files, team files, non-kit `README.md`, or `HEAD` commit (`git rev-parse HEAD` unchanged) were modified; if unexpected paths were modified, flag the repo loudly in the batch summary (and revert unexpected paths only if `--strict-docs-only` is passed).
   - Run `sh .agents/kit/check.sh` and `sh .agents/skills/interactive-docs/status.sh` after the run and record pass/fail per repo in the final summary table.

## Verification

- Add tests in `tests/run.sh`:
  - `sync-docs.sh --check` works across: (a) a single repo, (b) a workspace, and (c) a plain parent directory containing mixed non-git folders, non-kit git repos, clean kit repos, and dirty kit repos.
  - `sync-docs.sh --agent codex` / `agy` / `claude` using a fake executable on `PATH` verifies that clean repos are skipped, dirty repos invoke the exact expected non-interactive flags in the repo directory, and logs/summary output are written.
  - Post-run doc-only check flags if the mock agent touches a source file outside `LEARNING_DIR` / `*.agentk.md`.
- Run `sh tests/run.sh`, `sh .agents/kit/check.sh`, and `python3 guide/build.py`.
