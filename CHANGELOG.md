# Changelog

Each entry says what changed and what a repo must do when it upgrades
(`agent-kit upgrade`). Versions follow `VERSION`.

## 0.8.0 — 2026-10-31

Multi-repo workspaces, docs after a team pull, two new explanation skills,
and bug fixes.

**What an upgrading repo must do:** run `agent-kit upgrade` (or
`sh <agent_dev_kit>/install.sh .`). The install swaps the old kit hook
command in `.claude/settings.json`, `.claude/settings.local.json` and
`.codex/hooks.json` by itself when you never changed it; otherwise follow its
note. A repo whose `.codex/hooks.json` the kit made before 0.8 gets a note to
merge the new SessionStart hook. Then commit `.githooks/post-merge` and the
new skills if your share mode pushes agent files. Learning docs move to the
new explanation standard the next time they are refreshed; run
`learning-docs all` to rewrite them now.

- **Docs after a team pull.** New `pulled.sh` keeps a "docs checked up to"
  mark per branch in `.git/agent-kit/synced/` and lists other people's
  commits that changed code since then. It needs no git hooks, so a merge,
  a rebase, a fast-forward or a GUI pull all count. The session start (Claude
  Code and Codex) says so in one line and offers `docs-sync` with the new
  scope `pulled`; `post-merge` (now installed in every repo) says it after
  `git pull`; `wrap-up` and `agent-kit status` show the count. `docs-sync`
  says who fixes what: local kit docs after your yes, shared kit docs on a
  new branch for a pull request, the people's docs report only.
- **Multi-repo workspaces.** `agent-kit workspace` (new `WORKSPACE.md` and
  `templates/workspace/`) sets up a folder that holds several repos:
  `WORKSPACE.agentk.md` (repos, roles, contracts, rules), root pointers, and
  hooks that check every repo with the kit after a turn and remind the agent
  of `LINKS` between repos. `workspace.sh` has `init`, `add` (clone, git
  worktree or move), `scan` (finds repos you copied in), `where` (every
  workspace that holds a repo), `status` and `decline`. "Never install" is a
  note in that repo's `.git` folder; nothing else in the repo changes.
  `wire.sh` gives Codex a local pointer to the workspace map in own-mode
  repos too (`AGENTS.override.md`, kept out of git).
- **New skills `explain-d-ez` and `explain-d-in`.** Both follow the new
  `explain-standard.agentk.md`: about 80% of the way to ASD-STE100, and a
  quiz ladder of six questions from easy to hard (fundamentals, concepts,
  affected behavior). `explain-d-ez` writes Markdown (its own PR markers);
  `explain-d-in` builds an interactive page from `page-skeleton.html`
  (before/after and step-through widgets, a clickable quiz) and publishes a
  private Artifact in Claude Code, or a local HTML file outside the repo in
  other agents. `explain-diff` is unchanged, for comparison.
- **Learning docs use the explanation standard** and its quiz ladder;
  `writing-style.agentk.md` points them there.
- **Fixes.**
  - The hook commands fail quietly outside a git repo (before, they printed
    an error and exited 127, for example in a workspace folder).
  - The catch-up queue counts `__init__.py`, `_app.tsx` and paths with
    spaces.
  - Scripts read `.agents/agent-kit.conf` as text through the new `lib.sh`
    (before, some ran it as shell code).
  - The install no longer stages new files (`git add --chmod`), and handles
    `|`, `&` and `\` in config values. `--share` and `--maps` without a
    value name the fix.
  - Codex gets the SessionStart hook.

## 0.7.0 — 2026-10-22

Team repos: work beside the team's own AGENTS.md / CLAUDE.md, on this
computer only.

- **The first question in setup and upgrade: personal or team repo?** New
  `agent-files.sh` (read only) guesses from git (authors, remote, your
  share) and lists every agent file already here with its content, author
  and whether it is on the remote. New settings `REPO_KIND` and
  `AGENTS_USED`.
- **New `MAPS="beside"`** (team repos). The team's `AGENTS.md`, `CLAUDE.md`,
  `GEMINI.md`, settings, `.gitignore` and hooks are never edited. Your map
  is `AGENTS.agentk.md` (root and units). `SHARE` is always `none`:
  nothing of yours reaches the team's remote, and `check.sh` blocks a
  commit of any kit file, even with `git add -f`.
- **New `wire.sh`** connects your maps to each agent with local files that
  are never committed, and keeps the team's rules first:
  - Claude Code: `CLAUDE.local.md` per folder imports `@AGENTS.agentk.md`,
    and `@AGENTS.md` where the folder has no `CLAUDE.md` (a
    `CLAUDE.local.md` stops Claude reading `AGENTS.md` by itself).
  - Codex: `AGENTS.override.md` per folder holds the team's `AGENTS.md`,
    then your map (Codex reads it instead of `AGENTS.md`). It refreshes
    after a pull or checkout (new `post-merge` / `post-checkout` hooks), at
    session start and on the Stop hook; `check.sh` fails while it is stale.
  - Cursor: `.cursor/rules/agent-kit.mdc`.
  - Gemini / Antigravity: reported; the agent adds your map to
    `context.fileName` in `~/.gemini/settings.json` with your yes, or
    offers a note when the team's settings win.
  - `--plan` shows what it would do per agent, `--check` fails when stale,
    `--remove` undoes it. Files git tracks are never written.
- `install.sh --maps beside`: precise local ignore rules (never whole
  folders), Claude Code hooks in `.claude/settings.local.json`, kit skills
  beside the team's skills, git hooks only when the team has none.
- The Stop hook asks once when the agent edits a team agent file, and
  refreshes the wiring when a map changes. `docs-sync` lists conflicts
  between your map and the team's rules; `stale.sh` flags your map when the
  team's file in the same folder changed.

Upgrade: run `agent-kit upgrade`. It asks the new first question. For a
personal repo nothing changes. For a team repo whose `AGENTS.md` /
`CLAUDE.md` the kit took over in an older version, answer "team repo"; the
agent moves your rules into `AGENTS.agentk.md`, offers to restore the
team's files from git, and runs `install.sh --maps beside`.

## 0.6.0 — 2026-10-22

Plain-language setup, and the kit never edits your Markdown files.

- **Every Markdown file the kit writes ends in `.agentk.md`** (new setting
  `DOC_SUFFIX`):
  - a unit's detail doc is `README.agentk.md`;
  - the decision index is `DECISIONS.agentk.md`, with
    `docs/decisions/D-NNN-*.agentk.md` for each decision;
  - `PLAN.agentk.md`, the ledger, the learning docs;
  - the command card `KIT.agentk.md`, which replaces the section the kit
    added to the root `README.md`;
  - the kit's writing style `.agents/kit/writing-style.agentk.md`.

  `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` and `SKILL.md` keep their exact
  names; `check.sh` fails if one carries the suffix.
- **Your Markdown files stay yours.** `README.md`, `docs/*.md` and every
  other file without the suffix are read, never edited.
  - `docs-sync` reports drift in them in a separate "Your docs" table,
    with a sentence to paste in.
  - `stale.sh` labels each doc `kit` or `yours`.
  - Updating your own `README.md` still counts as documenting a commit.
- **Local share modes hide every `*.agentk.md`**, so kit detail docs no
  longer reach the remote in modes `learning` and `none`. Learning docs
  are still pushed in mode `learning`.
- **Setup in plain words, with choices.**
  - Each question explains itself and shows choices: the agent's proposed
    answer first, real alternatives, and "type your own" last.
  - Claude Code shows a choice box; other agents print a numbered list.
  - The first question offers "use your proposed answers for everything".
  - The settings are shown as a table in plain words before anything is
    written.
  - `agent-kit.conf` is rewritten in two parts: the basics, then
    fine-tuning, each setting with an example. The key names are
    unchanged.
- The "How to ask the user a question" and "Which files you may edit"
  rules live in the writing style; every skill follows them.

Upgrade: run `agent-kit upgrade`. Nothing is required: without
`DOC_SUFFIX` in `.agents/agent-kit.conf`, the old names (`README.md` in a
unit, `DECISIONS.md`) keep working. The agent offers to rename the kit's
files to `*.agentk.md` with `git mv`. It asks you which unit `README.md`
files the kit wrote. If the root `README.md` has the kit's "Agent context"
section, it offers to move that section to `KIT.agentk.md`. The install
replaces `.agents/kit/writing-style.md` with `writing-style.agentk.md`.

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
