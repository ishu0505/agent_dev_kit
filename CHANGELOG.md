# Changelog

Each entry says what changed and what a repo must do when it upgrades
(`agent-kit upgrade`). Versions follow `VERSION`.

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
`lineage` or `scaffold` (like docu_nom_nom_69) is told so once; answer
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

First release, extracted from docu_nom_nom_69's hand-made setup.

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
