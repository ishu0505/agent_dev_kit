# Changelog

Each entry says what changed and what a repo must do when it upgrades
(`agent-kit upgrade`). Versions follow `VERSION`.

## 0.14.0 — 2026-11-10

A new skill, `repo-md-sync`, updates the repo's own Markdown files
(`README.md`, `CONTRIBUTING.md`, `docs/*.md`: the ones people wrote) to
match the code, but only the files the user picks and only the lines the
user approves. And you can now see that the kit is in use: the agent's
first reply names the kit version, the level (repo, workspace or both) and
the maps; every session start is logged; `agent-kit doctor` reports each
repo and agent in a folder.

**What an upgrading repo must do:** run `agent-kit upgrade`. The agent then
offers to add the session-line sentence (under "Where things are" in
`templates/docs/AGENTS.root.md`, or `AGENTS.beside.md`) to the root map:
agents without kit hooks, such as Cursor, read it only there. Claude, Codex
and Antigravity get the line from the session start without it. To turn
the line off, set `SESSION_BANNER="off"` in `.agents/agent-kit.conf`. The
"Docs" line of an older root map may keep "never edit it".

- **Session line**: the session start (`sessions.sh banner`) asks the agent
  to begin its first reply with "agent-kit 0.14.0 · level: repo · map:
  AGENTS.md (via CLAUDE.md)", once, and later "agent-kit: now also using
  <path>" when it first reads another folder's map. The level is `repo`,
  `repo + workspace` (Claude inside a repo of a workspace: it loads the
  workspace `CLAUDE.md` too), `repo (workspace map ... read when a change
  crosses repos)` (the other agents there), or `workspace` (an agent started
  in the workspace folder: one line for the workspace, with each repo's kit
  version). `SESSION_BANNER="off"` (repo config or `workspace.conf`) stops
  it.
- **Session log** (`sessions.sh`, kit-owned): each session start adds a line
  to `.git/agent-kit/sessions.log` (time, agent, kit version, branch,
  level); it stays on this computer. `sessions.sh report` shows each agent's
  wiring and last session; `agent-kit status` includes it.
- **Cursor in a team repo**: the local `.cursor/rules/agent-kit.mdc`
  (written by `wire.sh`, never committed) now loads the root map with
  `@AGENTS.agentk.md` and asks for the session line with the repo name, so
  in a multi-repo Cursor window each repo says it is loaded. The session
  line names the repo everywhere (`repo: <folder>`).
- **`agent-kit doctor [folder]`** (`doctor.sh` in the kit): for a repo, a
  workspace or any folder of repos (a Cursor workspace), lists each repo's
  kit version or "no kit", its level, and per agent the wiring and last
  session. Cursor has no kit hooks, so it is never logged: its sign is the
  first-reply line.

- **`repo-md-sync`** (kit-owned, on request only): `list.sh` lists the
  people's Markdown files with the date each was last updated and how many
  other files changed in its scope since. Kit docs (`.agentk.md`), the agent
  files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `SKILL.md`), `.agents/`,
  `.claude/` and `LEARNING_DIR` are left out. The user picks files, then
  approves each file's edits. It keeps the file's voice and format and never
  commits. In a team repo, the edits go to the team in the user's pull
  request.
- **It never starts on its own**: only when the user names it or asks to
  update those docs. `docs-sync` still only reports drift in the people's
  docs and names the skill in one line; `wrap-up` and `catch-up` never
  start it.
- **Maps and writing style**: the people's Markdown is edited only through
  `repo-md-sync`, when the user starts it.

## 0.13.1 — 2026-11-09

`wrap-up` and `docs-sync` now ask whether to sync the interactive learning
pages when they no longer match their learning docs.

**What an upgrading repo must do:** run `agent-kit upgrade`. Nothing else;
in a root map from an older kit, "only when the user names them" for
`interactive-docs` may stay as it is.

- **`wrap-up`** (step 3) and **`docs-sync`** (new step 5a): when
  `<LEARNING_DIR>/interactive_l_docs/` has pages, they run
  `interactive-docs/status.sh` and, if pages are stale, missing or
  orphaned, ask once: "Sync them now?" On yes, `interactive-docs sync`
  runs. A repo with no pages is never asked.
- **`interactive-docs`**: may run after that yes, not only when named.

## 0.13.0 — 2026-11-09

Antigravity (the agy CLI, the IDE and the app) gets the same session start
and Stop hook as Claude Code and Codex.

**What an upgrading repo must do:** run `agent-kit upgrade` (or
`sh <agent_dev_kit>/install.sh .`). It creates `.agents/hooks.json`, the
workspace hook file Antigravity reads. If the repo already has one, the
install keeps it and says to merge the `"agent-kit"` entry from
`templates/config/agy-hooks.json`. Restart Antigravity, or start a new
conversation, so it loads the hooks; `/hooks` in agy shows them.

- **`agy-hook.sh`** (kit-owned): turns Antigravity's hook events into the
  kit's own. At session start it returns the kit's lines (queue, pulled
  commits, todo count, the coding standard) as one system message. At a stop
  it runs the Stop hook and answers `{"decision": "continue", "reason": ...}`
  when checks fail or the docs step is due. Antigravity has no
  `stop_hook_active`, so the kit lets the stop right after a "continue"
  through itself; it never continues after an error or the step limit.
- **Team repos**: Antigravity reads only `AGENTS.md` and `GEMINI.md` by
  name, so its session start now tells it to read `AGENTS.agentk.md`. The
  hook file is under `.agents/`, which stays local there.
- **`wire.sh`** reports Antigravity from `.agents/hooks.json`; the
  `context.fileName` step is now for Gemini CLI only.
- **`check.sh`** also checks `.agents/hooks.json` for hard-coded paths and
  missing scripts.

## 0.12.0 — 2026-11-08

A todo list: ideas and follow-ups for a later session, kept in the repo.

**What an upgrading repo must do:** run `agent-kit upgrade` (or
`sh <agent_dev_kit>/install.sh .`). It installs `todo.sh`, its template and
the `todo` skill. The root map is the repo's, so the upgrade agent asks
before it adds this line to the map's `## Tasks` block: "Ideas for later go
to the todo list (`TODO.agentk.md`, the `todo` skill), not into this task."
`TODO.agentk.md` is made on the first item. It follows `SHARE` like every
kit doc (pushed in `agent` and `all`, local in `learning` and `none`, always
local in a team repo). For other categories than task, bug, chore and
experiment, add `TODO_CATEGORIES="..."` to `.agents/agent-kit.conf`.

- **`todo` skill**: add an item (the agent picks the category and fills
  `From:` and `Refs:` with files, docs or folders that give context), list
  them, start one (reads its refs as context, not as the limit of the work,
  and can open a task file) and finish one (the item is deleted; a decision
  or an experiment result goes to `lineage` first, with your yes).
- **`todo.sh`**: `add`, `list [category|open|doing]`, `show`, `set`,
  `done`, `refs`, `count`. IDs are `T-NNN` and never reused.
- **Session start** prints one line when the list has items, such as
  `3 todo(s) in TODO.agentk.md (1 experiment, 1 bug, 1 chore); doing: T-002`.
- **`check.sh`** fails on an unknown category or status and on a repeated
  ID, and warns when a ref path is gone.
- **`lineage`** offers an experiment's follow-ups as todo items; **`wrap-up`**
  asks to mark the finished item done (`Todo: T-NNN` in the task file).

## 0.11.1 — 2026-11-06

A clearer naming rule in the coding standard.

**What an upgrading repo must do:** run `agent-kit upgrade` (or
`sh <agent_dev_kit>/install.sh .`). It overwrites the kit-owned
`.agents/kit/coding-standard.agentk.md`; nothing else changes.

- **`coding-standard.agentk.md`**, rule 4: a name says what the function
  does or what the variable holds; several full words are fine, joined in
  the language's casing (`snake_case` with `_`, `camelCase`, and so on);
  new names match the terms, prefixes and patterns already in the repo.

## 0.11.0 — 2026-11-05

One coding standard for every repo with the kit, loaded without a skill.

**What an upgrading repo must do:** run `agent-kit upgrade` (or
`sh <agent_dev_kit>/install.sh .`). It installs
`.agents/kit/coding-standard.agentk.md`, and the SessionStart hook starts
printing it. The root map is the repo's, so the upgrade agent asks before it
adds this line under `## Code style` (in a team repo, under `## My rules` of
`AGENTS.agentk.md`): "Before you plan, write or change code, follow
`.agents/kit/coding-standard.agentk.md`. The rules here win when they
conflict." Agents without the kit's hook (Gemini, Grok, Cursor, Codex in a
team repo) find the standard only through that line. To turn the standard
off, add `CODING_STANDARD="off"` to `.agents/agent-kit.conf`; a missing
line means on.

- **`coding-standard.agentk.md`** (kit-owned): KISS for every language:
  simplicity over cleverness, reuse first, function and file sizes, full-word
  idiomatic names, guard clauses and low nesting, explicit error handling,
  an OWASP security baseline, then: the repo's own rules win, docstrings and
  why-comments, and change only what the task needs.
- **Session start** prints the standard after its other lines, in every
  Claude and Codex session and again after compaction (about 3,500
  characters). `AGENT_KIT_SKIP_STANDARD=1` skips it; the workspace hook
  uses that and prints the standard once for all repos.
- **Maps, plans, wrap-up:** the map templates point to the standard; the
  task-file template has a `Standard:` line in its plan (the code reused, and
  whether a new layer is needed); `wrap-up` reviews the lines the branch
  changed against the standard and proposes fixes, applied only on a yes.
- **Setup** question 4 explains the standard and asks only for the repo's
  own rules.

## 0.10.0 — 2026-11-01

Two skills that run only when you name them: interactive learning docs,
and an architecture review for scale and latency.

**What an upgrading repo must do:** run `agent-kit upgrade` (or
`sh <agent_dev_kit>/install.sh .`). It installs the two skills; nothing
else changes, and no agent starts them by itself. Both write inside
`LEARNING_DIR`, so they follow the share mode of the learning docs (local
in `agent` and `none`, committed in `all` and `learning`) and stay local in
team repos with no new exclude rule. If your share mode pushes agent files,
commit `.agents/skills/interactive-docs/` and `.agents/skills/arch-emulator/`.

- **`interactive-docs`** rewrites each learning doc as one self-contained
  HTML page in `<LEARNING_DIR>/interactive_l_docs/` (same path, `.html`):
  a clickable diagram of the parts, a step-through of one request on the
  same diagram (with Play), a clickable database diagram (tables, keys,
  who writes and reads each), failure toggles, code links and a clickable
  quiz, plus `index.html`. Modes: `build`, `sync` (only pages whose
  learning doc changed) and `status`. Each page records the learning
  doc's `source_commit` in a marker; the new read-only
  `.agents/skills/interactive-docs/status.sh` lists pages that are
  `missing`, `stale`, `current` or `orphan`, and says when the learning
  doc itself is stale. `docs-sync` and `learning-docs` never touch these
  pages: only `interactive-docs sync` updates them.
- **`arch-emulator`** reviews the repo for scale and latency, read only: the
  parts and links (calls that wait, messages that do not), the repo and
  service structure, request paths with timeouts and retries, a capacity
  estimate per part with the source of each number (measured, repo config,
  provider docs with a date, or a stated assumption), what fills up first
  and at what load, the pros, cons and limits of each tool (queues such as
  SQS, HTTP, databases, caches, serverless), what is good, the gaps with a
  confidence, tests to run (on staging, never production), and fixes in
  three tiers: quick, medium, long term. It writes a dated
  `<LEARNING_DIR>/architecture/YYYY-MM-DD-review.agentk.md` and a page with
  a load emulator (a slider for users or requests per second; bars per
  part; Little's Law for requests in flight). Reviews are snapshots: their
  front matter uses `reviewed_paths`, so `docs-sync`, `stale.sh` and the
  Stop hook skip them. A rerun compares with the last review.
- `docs-sync` and `learning-docs` say that the two subfolders are not
  theirs.

## 0.9.0 — 2026-10-31

Maps that warn, task files, and hidden links: changes for accuracy. They
help an agent edit the right file, see a breakage that search does not show,
and keep its notes when the chat gets compacted.

**What an upgrading repo must do:** run `agent-kit upgrade` (or
`sh <agent_dev_kit>/install.sh .`). The install adds `/.agents/work/` to
`.git/info/exclude`, so task files never reach git. Nothing else is
required: a map without the new sections passes the checks as before. The
upgrade offers, once: add the "Tasks" block from `templates/docs/AGENTS.root.md`
(or `AGENTS.beside.md`) to the root map, and run `candidates.sh` to find
warning rows for you to confirm. If your share mode pushes agent files,
commit `.agents/kit/task.sh`, `task.agentk.md` and `candidates.sh`.

- **Warning rows in the maps.** Three optional sections in every map
  template: "Do not read unless asked" (generated code, test data, old
  copies), "Lookalikes" (the live folder, not the one with a similar name)
  and "Hidden links" (a change here breaks that file in a way search does
  not show: a config key, a name written as text, a file another language
  reads). Each row is a fact you confirmed, at most five a section; scripts
  propose rows, never write them. `check.sh` checks every path in them,
  from the map's folder or the root, with `**` globs, and a stale row fails
  with its fix. Editing a path in a warning row asks for no docs step.
- **`candidates.sh [folder]`** (read only) lists rows to confirm: folders
  named like test data, snapshots or generated code, files a tool generated
  (by name, or a `DO NOT EDIT` / `@generated` header), big data files, and
  folders that look like an old copy (`billing_legacy/` beside `billing/`).
  It never guesses hidden links. Setup (question 10), `scaffold` and the
  upgrade use it.
- **Hidden links in the Stop hook.** When a turn changes the first path of
  a "Hidden links" row and not the second, the Stop hook names the second
  file once per session. New `check.sh --links` prints the rows.
- **Task files.** For work that spans sessions or units, needs your OK on
  a plan, or is an investigation to keep, the agent opens
  `.agents/work/<name>.agentk.md` (`task.sh new`) with Goal, Scope, Found,
  Decisions, Plan, Done, Next and Open questions, so a fresh session
  continues from the file. Never committed, in every share mode and in team
  repos; `check.sh` fails when one is tracked. The session start names open
  tasks; the Stop hook asks once per session to update the active task of
  the branch when code changed and the file did not. `wrap-up` offers
  `lineage` for its decisions, proposes the map rows the task taught, then
  closes it (`task.sh close`) or keeps it paused. The root map's new
  "Tasks" block says when to open one.
- `docs-sync` checks that warning rows are still true (an old folder that
  live code uses again).

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
  - The install no longer stages new files on macOS and Linux (only on
    Windows, where git cannot otherwise record the executable bit), and handles
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
