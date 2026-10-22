# Changelog

Each entry says what changed and what a repo must do when it upgrades
(`agent-kit upgrade`). Versions follow `VERSION`.

## 0.5.0 — 2026-10-20

Less friction, less drift, people in the loop.

- **Only what a change breaks blocks.** The pre-commit runs
  `check.sh --staged`: a map the commit edits, a path it deletes, a unit it
  adds code to. Problems from other commits do not block. New modes:
  `--since <ref>` (CI on a pull request), `--changed <paths>` (the Stop
  hook), `--ci` (no "is the hook active" check), `--run-commands`.
- **Every map is checked**, at any depth, and paths in prose too (a word in
  backticks with a `/` or a file extension). `<!-- agent-kit: skip -->`
  leaves a line out. Paths with spaces work. Optional: `CHECK_ENV="yes"`
  (env var names in maps must appear in code), `RUN_COMMANDS_MAPS` (CI runs
  a map's `## Run` / `## Check` blocks).
- **Maps only where they pay off.** `MAP_MIN_FILES` / `MAP_MIN_LINES`: a
  smaller unit needs only a row in a map. `MAP_REQUIRED` / `MAP_EXEMPT`
  override per folder. New `map-rows.sh` suggests rows from the tree. The
  root map template is shorter.
- **Existing hooks stay on.** The install sets `core.hooksPath` only when
  the repo has no other hook setup; for pre-commit, lefthook, husky or
  `.git/hooks` it prints the lines to add.
- **CI**: `install.sh --ci` adds `.github/workflows/agent-kit.yml`.
- **Per-user files** (`.claude/settings.local.json`, `CLAUDE.local.md`) are
  git-ignored, so they no longer fail the check.
- **A quiet Stop hook.** It finds changes with `git status`, not the
  transcript (shell edits and subagents count). Nothing changed: nothing
  runs. It asks for the docs step once per file, and only for files a map
  names, files added to or removed from a mapped folder, or
  `INTERFACE_GLOBS`; only a README or map above the file satisfies it.
  Stale learning docs are noted, never blocking. New SessionStart hook
  (Claude Code) sets the baseline and mentions what waits.
- **Code written by hand**: a post-commit hook queues commits that changed
  code without its docs (`[no-docs]` opts out). New `catch-up` skill:
  explains each change, asks the intent, proposes docs, docstrings and
  comments; applies only what you approve.
- **New `wrap-up` skill** for the end of every task: checks, `docs-sync`
  for the branch, asks before refreshing stale learning docs, writes the
  pull request section.
- **New `explain-diff` skill**: background, intuition, code walkthrough
  and a five-question quiz in the pull request description.
- **One file per decision** (`DECISIONS_DIR`, default `docs/decisions`),
  with `DECISIONS.md` as an index that `check.sh` keeps in step.
- **Targeted `docs-sync`**: new `stale.sh` lists only docs whose anchors
  (named paths, `source_paths`) changed; `docs-sync` defaults to the branch.
- **One writing style** (`.agents/kit/writing-style.md`): ASD-STE100,
  written for an intern, plus rules for docstrings; every writing skill
  follows it.
- `check.sh` notes a newer kit version and a non-empty catch-up queue.
- `.claude/skills/**` keeps LF line endings too, so a Windows clone of a
  copy-mode repo no longer fails "out of sync". An existing Windows clone:
  run `rm -rf .claude/skills && git checkout -- .claude/skills` once after
  the upgrade.
- When a local share mode would untrack files teammates committed, the
  install warns and needs `--confirm-untrack` to print the command.

Upgrade: run `agent-kit upgrade`. Then:

1. The repo's config is kept, so the new settings are off until you add
   them: copy `MAP_MIN_FILES`, `MAP_MIN_LINES`, `MAP_REQUIRED`,
   `MAP_EXEMPT`, `INTERFACE_GLOBS`, `CHECK_ENV`, `RUN_COMMANDS_MAPS` and
   `DECISIONS_DIR` from `templates/config/agent-kit.conf` and set them.
   Without the thresholds every unit still needs a map; without
   `DECISIONS_DIR` decisions stay in `DECISIONS.md`.
2. Merge the SessionStart hook from `templates/config/claude-settings.json`
   into `.claude/settings.json` (the install says so).
3. If the repo uses a hook manager, add the lines the install prints, then
   commit `.githooks/post-commit`.
4. `check.sh` now reads prose paths and every map at any depth: fix the
   dead paths it finds, or mark a line with `<!-- agent-kit: skip -->`.
5. Replace the "Keeping the docs true" section of the root `AGENTS.md`
   with the short "Docs" section of `templates/docs/AGENTS.root.md`.
6. Optional: `install.sh --ci`; split `DECISIONS.md` into files (the
   `lineage` skill offers it).

## 0.4.0 — 2026-10-18

Your skills are never lost, and existing repos get a house cleaning first.

- `install.sh` records a fingerprint of each kit skill it installs
  (`.agents/kit/skills.sum`). On upgrade it replaces a kit skill only when
  the repo never edited it. An edited skill is kept; a newer kit version
  waits in `.git/agent-kit/incoming/<skill>/` for the agent to merge, and
  is offered once. A skill the repo had before the kit, with a kit skill's
  name, is kept too.
- New setting `OWN_SKILLS`: skills the kit never touches.
- New `inventory.sh` (read only): every agent and doc file, grouped, with
  git state, last commit, size, staleness and duplicates.
- BOOTSTRAP phase 1b, house cleaning: before setup in existing projects
  and before every upgrade, the agent proposes keep / merge / own / remove
  per file and asks one group at a time. On its own: `agent-kit cleanup`.

Upgrade: run `agent-kit upgrade`. The four kit skills are unchanged since
0.3.0, so unedited copies are recognised and recorded. A repo with its own
`lineage` or `scaffold` is told so once; answer
"it is ours" and the agent adds them to `OWN_SKILLS`.

## 0.3.0 — 2026-10-18

Share modes: choose what reaches the remote repo.

- New `SHARE` setting: `agent` (default: agent files pushed, learning docs
  local), `all`, `learning` (learning docs pushed, agent files local) or
  `none`. Set it with `install.sh --share <mode>`; the setup interview
  asks.
- Rules for local files go in `.git/info/exclude` and `.git/info/attributes`
  (never committed); shared rules go in `.gitignore` and `.gitattributes`,
  inside a marked `agent-kit` block that each install rewrites.
- `check.sh` enforces the mode: a local file that is tracked or staged
  fails the check and so blocks the commit.
- Changing the mode prints the `git rm -r --cached` command for files that
  must stop being tracked.

Upgrade: run `agent-kit upgrade`. The repo keeps `SHARE="agent"`, which is
how 0.1 and 0.2 behaved. The old unmarked learning-docs line in
`.gitignore` and LF rules in `.gitattributes` are replaced by the marked
block.

## 0.2.0 — 2026-10-18

Works on Windows (Git Bash), macOS and Linux; CI tests all of them.

- New `SKILLS_LINK` setting: `symlink` (default) or `copy`. Where a symlink
  cannot be made, `.agents/kit/sync-skills.sh` switches the repo to copy
  mode by itself. `check.sh` compares the copies and catches a symlink
  checked out as a plain file.
- `.gitattributes` rules keep the scripts LF; `check.sh` fails without them.
- Scripts are staged executable (`git add --chmod=+x`); `check.sh` fails
  when the pre-commit hook is not executable in git.
- The Stop hook finds `python3`, `python` or `py`, handles Windows paths,
  and both agent configs call it through `git rev-parse` instead of
  `$CLAUDE_PROJECT_DIR`.
- `check.sh` reads Markdown with Windows line endings and catches Windows
  home paths in hook configs.
- `install-global.sh` copies the global skill where symlinks fail and
  records the kit folder in `kit-path`.

Upgrade: run `agent-kit upgrade`. It adds `sync-skills.sh`, the LF rules
and the executable bits. Add `SKILLS_LINK="symlink"` to
`.agents/agent-kit.conf` (or `copy` if the team uses Windows). In
`.claude/settings.json`, replace the old Stop hook command with the one in
`templates/config/claude-settings.json`.

## 0.1.0 — 2026-10-18

First release, extracted from a hand-made setup in one project.

- `check.sh` (POSIX sh): map size, dead paths, unit README / map / pointer
  files, one skill copy, agent files tracked, portable hooks, pre-commit
  active, experiment ledger outcomes, learning docs never tracked.
- Stop hook for Claude Code and Codex: runs the checks after an editing turn
  (shell edits included) and asks for the docs step after a code edit.
- Skills: `lineage`, `scaffold`, `docs-sync` (check / fix), `learning-docs`
  (ASD-STE100, code references, quizzes with hidden answers).
- `install.sh` (also the upgrade), `install-global.sh` (the `agent-kit`
  skill for Claude Code, Codex, Cursor, Muse, Antigravity, Gemini CLI).

Upgrading from a hand-made setup: run `agent-kit upgrade`; it lists old
hooks and check scripts the kit replaces, and proposes removing them.
