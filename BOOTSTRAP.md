# Agent kit bootstrap

The setup prompt for any coding agent (Claude Code, Codex, Cursor,
Antigravity, Gemini CLI, Muse; app or CLI) in a repo of any language, on
macOS, Linux or Windows. Run the agent inside the target repo and say:

    Read <path to agent_dev_kit>/BOOTSTRAP.md and follow it.

Or use the global skill: `agent-kit setup` (Claude Code: `/agent-kit setup`).
Add `mode: new`, `mode: existing` or `mode: upgrade` to force a case.

---

You are installing **agent_dev_kit** into this repository. `KIT` below means
the folder that contains this file. The kit gives the repo:

1. **Maps**: short `AGENTS.md` files so any agent works here without reading
   all the code: one at the root, and one per unit big enough to need it.
   `CLAUDE.md` / `GEMINI.md` only import them.
2. **Lineage**: `DECISIONS.agentk.md`, the index of every decision and its
   reason (one file per decision); an optional experiment ledger.
3. **Skills** in `.agents/skills/`: `lineage`, `scaffold`, `docs-sync`,
   `learning-docs`, `wrap-up`, `catch-up`, `explain-diff`, `explain-d-ez`,
   `explain-d-in`.
4. **Checks**: `.agents/kit/check.sh`, run on every commit (only what the
   commit breaks blocks), after every agent turn that changed files, and in
   CI, so the docs stay true.
5. **Humans in the loop**: code written by hand is queued for `catch-up`
   (explain it, propose docs and docstrings, apply what the user approves);
   every pull request gets an `explain-diff` section with a quiz.
6. **Learning docs**: `learning_docs/` that teach people the system,
   refreshed at the end of a task.
7. **A share mode** (`SHARE`): which of these reach the remote repo.

**Names.** Every Markdown file the kit writes ends in `DOC_SUFFIX`
(`.agentk.md`): `README.agentk.md`, `DECISIONS.agentk.md`,
`KIT.agentk.md`. `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` and `SKILL.md` keep
their exact names, because agents load them only by those names. **Never
edit, rename or delete a Markdown file the kit did not write** (`README.md`,
`docs/*.md` and the rest): read it, and report drift in it. Below, a name
like `DECISIONS.agentk.md` means `DECISIONS<DOC_SUFFIX>`.

The scripts and skills are ready-made in `KIT/templates/`; copy them, do not
rewrite them. Your work is the repo-specific part: the config, the maps,
the decisions and the plan. Work in the phases below, do not skip ahead, and
write nothing before phase 3 is approved (phase 4 starts with the install).

## Phase 0 — Personal or team repo, then which case

**Not a repo, but a folder of repos?** If `git rev-parse` fails here and
folders below hold `.git`, this is a multi-repo workspace: follow
`KIT/WORKSPACE.md` instead. If this repo's parent (or grandparent) folder
holds other repos, finish this setup, then offer once: "This repo sits next
to other repos (<names>). Set up the folder as a workspace?" (`agent-kit
workspace`, recommended when the repos work together, such as a frontend
and its API).

**The first question, always** (setup and upgrade alike, before anything
else). Run `sh KIT/templates/kit/agent-files.sh .` (read only). It prints a
guess for the repo (authors, remote, my share of the commits) and every
agent file already here (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, ...) with
who wrote it and whether it is on the remote. Then ask, with choices:

```
Is this your personal repo or a team repo?
  1. Team repo: other people push here (recommended: <the reason from git>)
  2. Personal repo: only I work here
  3. Something else: type your own answer
```

On upgrade, show the stored answer instead: "This repo is set as a team
repo (`REPO_KIND` in the config). Still right?" with yes / it changed /
type. The answer goes into `REPO_KIND`.

- **Team repo**: by default the kit works **beside** the team
  (`MAPS="beside"`, `SHARE="none"`): my map is `AGENTS.agentk.md`, the
  team's `AGENTS.md` / `CLAUDE.md` / settings are never edited, and nothing
  of mine is ever pushed. Agents load the team's files and mine together
  through local files (`.agents/kit/wire.sh`). Offer the other choice only
  as "the team agreed to share the kit" (`MAPS="own"`, a shared mode).
- **Personal repo**: the kit owns `AGENTS.md` (`MAPS="own"`), as below.

Then look at the repo, tell me which case you see and wait for my OK:

- **A. Existing project, no kit** (`mode: existing`): it has code and no
  `.agents/kit/`.
- **B. New project from a goal** (`mode: new`): empty or nearly empty.
- **C. Kit installed** (`mode: upgrade`): `.agents/kit/VERSION` exists.
  Compare it with `KIT/VERSION` and read `KIT/CHANGELOG.md` for what
  changed since. Then do phase 4 step 1 (the install upgrades the kit
  files), list each part below as present, partial or missing, and interview
  me only about the missing and partial parts. Keep all existing content.
- An older hand-made setup (maps or checks but no `.agents/kit/`) is case C
  without a version: also list what the old setup has that the kit replaces
  (old hooks, old check scripts, old hook entries in `.claude/settings.json`
  and `.codex/hooks.json`) and ask about removing each one. Fill
  `.agents/agent-kit.conf` from the old setup (unit folders, ledger path,
  line limits).
- **Case C, a team repo the kit took over** (`MAPS` is not `beside`, but I
  now answer "team repo" and the team wants its files back): move my rules
  from the kit's `AGENTS.md` into `AGENTS.agentk.md`, show me the team's
  last version of each file the kit changed (`git log` / `git show`), and
  offer to restore it with `git checkout <commit> -- <file>`. Then run
  `install.sh --maps beside` and commit only the restored team files, after
  my yes.
- **Case C from kit 0.8 or older** (no `.agents/kit/task.sh` before the
  install): the install adds task files and the candidate list. Offer once,
  with choices: add the "Tasks" block from `KIT/templates/docs/AGENTS.root.md`
  (or `AGENTS.beside.md`) to the root map (recommended), and run interview
  question 10 for the warning rows (recommended), or skip. Change nothing
  else in the maps.
- **Case C from kit 0.5 or older** (`DOC_SUFFIX` is missing from
  `.agents/agent-kit.conf`): the kit's files still have plain names. List
  them: `DECISIONS.md`, the decision files, `PLAN.md`, the ledger, the
  learning docs, and each unit `README.md` that looks like the kit's
  (the `scaffold` shape: a short detail page the map points to). Ask me
  about each unit `README.md`: the kit's, or ours? Then offer, with
  choices: rename the kit's files to `.agentk.md` now (recommended), or
  keep the plain names. On "rename": `git mv` each file, fix the paths in
  the maps and `LEDGER`, then add `DOC_SUFFIX=".agentk.md"` to the config.
  On "keep": add `DOC_SUFFIX=""`. If the root `README.md` holds the kit's
  "## Agent context" section, offer to move it into `KIT.agentk.md`.

Cases A and C go through **phase 1a** and **phase 1b, house cleaning**,
after exploring and before anything is installed. Case B has nothing to
clean.

## Phase 1 — Explore (read only; case B skips to phase 2)

- List the tree; skip dependency, build and generated folders
  (`node_modules/`, `.venv/`, `vendor/`, `target/`, `build/`, `dist/`,
  `bin/`, `obj/`, `third_party/`, ...).
- Read the root README, CI config, Dockerfiles and every build file
  (`package.json`, `pyproject.toml`, `go.mod` / `go.work`, `Cargo.toml`,
  `CMakeLists.txt`, `meson.build`, `Makefile`, `pom.xml`, `build.gradle`,
  `*.sln` / `*.csproj`, `Gemfile`, `composer.json`, `Package.swift`,
  `pubspec.yaml`, `mix.exs`, Bazel files, `justfile`).
- Read existing agent and decision docs: `AGENTS.md`, `CLAUDE.md`,
  `GEMINI.md`, `.cursor/rules`, `.github/copilot-instructions.md`, ADRs,
  `docs/`.
- Find the **units**: folders a developer works inside as a whole. Build
  files usually name them (workspaces, Go `cmd/<app>` and `internal/<pkg>`,
  Cargo members, CMake subdirectories, Gradle modules, .NET projects).
- Find the real commands for build, run, test, lint and format.
- Note conventions (naming, layout, errors, tests) and invariants (one
  place that does X, generated files, migrations, contracts).
- Run `sh KIT/templates/kit/candidates.sh .` (read only). It lists folders
  and files that look like test data, generated code, or an old copy of
  another folder. Keep the list for interview question 10; do not trust it
  without my answer.

Report in under 30 lines: units, commands, conventions, existing docs,
unclear points.

## Phase 1a — Agent files already here (cases A and C)

For each agent file `agent-files.sh` listed, show me, in three lines: what
it contains (from its headings and text), who wrote it, and whether it is
on the remote. Then ask, one file at a time, with choices:

- **Mine** (the guess says YOURS or PROBABLY YOURS, and I confirm):
  1. Replace it with the kit's map; keep a copy in
     `.git/agent-kit/backup/<path>` (recommended when it was never pushed);
  2. Merge its rules into the kit's map;
  3. Keep it and work beside it;
  4. Something else: type it.
- **The team's** (TEAM FILE):
  1. Keep it untouched; my setup stays on this computer only (recommended);
  2. Merge it into the kit's map (only if the team agreed; the kit then
     owns and pushes `AGENTS.md`);
  3. Something else: type it.

Keeping any team file means `MAPS="beside"` and `SHARE="none"` for the whole
repo. House cleaning then marks the team's agent files "leave alone".

## Phase 1b — House cleaning (cases A and C; nothing is changed without my yes)

1. **Inventory.** Run `sh KIT/templates/kit/inventory.sh .` (read only). It
   lists every agent and doc file in groups: maps and pointer files, rules
   for other agents (`.cursorrules`, `.cursor/rules`, Copilot), skills,
   commands, hooks and agent settings, decisions and plans, learning docs,
   other Markdown. For each file it gives the git state, the last commit,
   the size, and notes: not changed for months, same content as another
   file, same name as a kit skill, repo-owned skill.
2. **Propose.** For each file, propose one action with a one-line reason:
   - **keep** as it is;
   - **merge** its content into a kit file (old rules into `AGENTS.md`, old
     decisions into `DECISIONS.agentk.md`, other agents' rule files into
     the maps so every agent reads the same rules), then remove it. Offer
     this only for agent files (old `CLAUDE.md` text, `.cursorrules`, old
     decision notes), never for a `README.md` or other docs people wrote;
   - **own**: a skill the repo keeps as its own, added to `OWN_SKILLS` in
     `.agents/agent-kit.conf`. Propose this for every repo skill that has a
     kit skill's name but different content;
   - **remove**: stale, duplicate, or replaced by the kit;
   - **leave alone**: not about agents or docs (data, generated output,
     reports), and every Markdown file people wrote (`README.md`,
     `docs/*.md`). Say so once for a whole folder instead of file by file.
3. **Ask one group at a time.** Show the group as a table (path, action,
   reason) and wait for my answer before the next group. Give choices:
   "do all as proposed (recommended)", "change some (name them)", "skip
   this group", "something else: type it". I may change any
   action. Never touch an existing skill without my yes.
4. **Apply** only what I approved. Remove tracked files with `git rm`
   (recoverable from history), untracked ones with `rm` after I confirm
   that path. Write merged content in the target file before removing the
   source. Do not commit.
5. **Record** the cleanup as one decision (with the `lineage`
   skill after phase 4): what was kept, merged, owned and removed, and why.

Run this phase again whenever I ask for `agent-kit cleanup`.

## Phase 2 — Interview

**How to ask.** Follow "How to ask the user a question" in
`KIT/templates/kit/writing-style.agentk.md`:

- one question at a time, in plain words, with no setting names;
- every question has choices: your proposed answer first, marked
  "(recommended)", with the reason you found in this repo; then one or two
  real alternatives; then "Not decided yet" where it fits; and last,
  always, "Something else: type your own answer";
- use your agent's question tool when it has one (Claude Code:
  AskUserQuestion); otherwise print the choices as a numbered list and
  accept a number or my own words.

**Fast path.** The first question also offers "Use your proposed answer
for every question; show me only the summary". If I pick it, go straight
to phase 3; I can still change any row there.

Record "not decided yet" as an open question. The setting each answer
fills is in brackets below; show it to me only in phase 3.

New project only (case B), first:

- **The goal.** Who uses it, what problem it solves, and what "working"
  means for the first version. Offer two or three short drafts from what I
  said, plus "type your own".
- **The first milestone**, and what is out of scope for it.
- **Language, framework and storage.** If I have not chosen, offer options
  with one reason each. The choice becomes a decision.
- **The planned parts** (services, apps, packages) and how they talk to
  each other: HTTP calls, a queue, events, files, function calls.
- **Hard limits**: budget, speed, privacy, platforms, licences.

Every case:

1. **What the repo is for**, in one line, and **what matters most** when
   two goals conflict. Example: "1. correct results, 2. low cost, 3. speed".
2. **Which coding agents you use.** Choices: Claude Code only; Claude Code
   and Codex; also Gemini CLI or Antigravity; also Cursor; type your own.
   (Sets `AGENTS_USED`, so the kit connects each one; and `POINTER_FILES`:
   `CLAUDE.md`, plus `GEMINI.md` for Gemini, when the kit owns the maps.)
3. **Which folders are separate parts**, like a service, an app or a
   package. Show what you found with sizes. Explain: "A big part (15 or more
   code files) gets its own short guide for agents. A small part gets one
   line in the main guide." Choices: your list (recommended), a wider or
   narrower list, "the whole repo is one part", type your own. (Sets
   `UNITS`, `UNIT_PARENTS`, and `MAP_MIN_FILES` / `MAP_MIN_LINES` /
   `MAP_REQUIRED` / `MAP_EXEMPT` when I want a part treated differently.)
4. **Code style rules** the agents must follow. Offer the ones you found
   (linters, formatters, naming).
5. **Rules a change must never break.** Example: "only `billing/` may call
   the payment provider". Offer the ones you found.
6. **The command that proves a change works** (tests, lint), and **whether
   CI should also run the kit's checks**. Choices: yes, add a GitHub Actions
   file (recommended when the repo uses GitHub); no; I use another CI (then
   tell me to run `sh .agents/kit/check.sh --ci` there).
7. **Decisions already made** and where their reasons are written. Each new
   decision becomes one file in `docs/decisions/`, listed in
   `DECISIONS.agentk.md`. Old decision records (ADRs) can stay where they
   are. (Sets `DECISIONS_DIR`.)
8. **Experiments or benchmarks** that decide what ships, and their folder.
   Choices include "none". (Sets `LEDGER`.)
9. **Learning docs** (lessons for people, with quizzes): who reads them,
   which flows matter most, which parts first. Choices include "later".
10. **Folders agents must never edit, and traps.** Generated code,
    vendored code, data. Then show the `candidates.sh` list as a table
    with your proposal for each row: "do not read unless asked",
    "lookalike of `<live folder>`", or "not a trap". Then ask once: "Does
    a change anywhere break a file far away in a way a search does not
    show (a config key, a name written as text, a file another language
    reads)?" Each confirmed row goes in the optional "Do not read unless
    asked", "Lookalikes" or "Hidden links" section of the nearest map, at
    most five rows a section. Write no row I did not confirm.
11. **What may go to GitHub.** Show this table and recommend one:

    | Choice | Agent files (maps, kit docs, settings) | Learning docs |
    |---|---|---|
    | 1. `agent` (usual) | go to GitHub | stay on this computer |
    | 2. `all` | go to GitHub | go to GitHub |
    | 3. `learning` | stay on this computer | go to GitHub |
    | 4. `none` | stay on this computer | stay on this computer |

    Say that "stay on this computer" files are hidden from git in a way
    that never reaches GitHub, and that a fresh clone or another computer
    does not get them. (Sets `SHARE`.)
12. **Your Markdown files.** Explain: "Every Markdown file the kit writes
    ends in `.agentk.md` (`README.agentk.md`, `DECISIONS.agentk.md`). The
    kit never edits your other Markdown files, such as `README.md`; it reads
    them and tells you when one no longer matches the code. `AGENTS.md` and
    `CLAUDE.md` keep their names, because agents need them." Choices: OK,
    use `.agentk.md` (recommended); use another ending (type it); use plain
    names like kit 0.5 (the kit may then write `README.md` files in
    parts that have none). (Sets `DOC_SUFFIX`.)
13. **How the repo runs git hooks today**: none, pre-commit, lefthook,
    husky, or scripts in `.git/hooks`. The install never switches existing
    hooks off; it prints the lines to add.
14. **Operating systems the team uses.** Windows without symlink support
    gets a copy of the skills folder; the install picks that by itself when
    it has to. (Sets `SKILLS_LINK`.)

## Phase 3 — Propose

Show three things and wait for my approval:

1. The files you will create, one line each. Every new Markdown file ends
   in `DOC_SUFFIX` except `AGENTS.md` and the pointer files. Say "none of
   your existing files change" when that is true; else list each one.
2. The settings as a table in plain words:

   | Setting | Your answer | What it means |
   |---|---|---|
   | `UNIT_PARENTS` | `services` | each folder in `services/` is a part |

3. A draft of the root `AGENTS.md`.

## Phase 4 — Build

1. **Install** (all cases; this is also the upgrade):
   `sh KIT/install.sh --share <mode> .` (on Windows, run every kit command
   in Git Bash). Add `--ci` when I want the checks in GitHub Actions. In
   case C, leave out `--share` to keep the repo's mode; pass it only when I
   ask to change the mode. In a team repo kept beside the team, use
   `sh KIT/install.sh --maps beside .` instead: it forces `--share none`,
   writes no `.gitignore`, `.gitattributes`, `.claude/settings.json` or
   other team file, puts the Claude Code hooks in
   `.claude/settings.local.json`, adds kit skills beside any team skills,
   and adds git hooks only when the team has none. If it prints a WARNING that teammates committed
   the agent files a local mode stops sharing, stop and ask me; pass
   `--confirm-untrack` only after I say the team agreed.
   It copies `.agents/kit/`, the kit skills, `.githooks/pre-commit` and
   `post-commit`,
   creates `.agents/agent-kit.conf`, `.claude/settings.json`,
   `.codex/hooks.json`, `.claude/skills` (a link, or a copy where symlinks
   fail), writes the ignore and LF rules for the share mode (shared rules in
   `.gitignore` / `.gitattributes`, local ones in `.git/info/`), sets
   `core.hooksPath` when no other hook setup exists (else it prints the
   lines to add), and, when agent files are shared, stages the scripts as
   executable. It never overwrites repo-owned files. Kit skills are
   replaced only if the repo never edited them (fingerprints in
   `.agents/kit/skills.sum`); skills in `OWN_SKILLS` are never touched. Do
   everything it prints under "For the agent". For each skill it kept
   because the repo edited it or had its own, ask me: is it the repo's own
   (add it to `OWN_SKILLS`), or should it take the kit's update (merge the
   new version from `.git/agent-kit/incoming/<skill>/` into it, keeping the
   repo's additions; `KIT/CHANGELOG.md` says what changed)? The kit offers
   each update once: the next upgrade keeps the merged skill.
2. **Config**: fill `.agents/agent-kit.conf` from the interview.
3. **Maps**. In a team repo (`MAPS="beside"`): the root `AGENTS.agentk.md`
   from `KIT/templates/docs/AGENTS.beside.md`, unit maps `AGENTS.agentk.md`
   from `AGENTS.unit.md`, no pointer files, and nothing the team's files
   already say. Otherwise: the root `AGENTS.md` from `KIT/templates/docs/AGENTS.root.md`
   (at most `TOP_MAP_MAX` lines; its rows for `DECISIONS.agentk.md` and
   `KIT.agentk.md` use the real names), then one map per first-level folder that
   needs one, then each unit with the `scaffold` skill
   (`KIT/templates/docs/AGENTS.unit.md`, at most `UNIT_MAP_MAX` lines). One
   pointer file per `POINTER_FILES` entry beside every map, containing only
   `@AGENTS.md`. Map only paths that exist. Write the optional warning
   sections ("Do not read unless asked", "Lookalikes", "Hidden links") only
   with rows I confirmed in question 10, and leave out a section with no
   rows. Keep the root map's "Tasks" block.
4. **Lineage**: `DECISIONS.agentk.md` from `KIT/templates/docs/DECISIONS.md` (the
   index), and one file per decision from `KIT/templates/docs/decision.md`
   in `DECISIONS_DIR`, seeded with the decisions from the interview (write
   "not recorded" for a reason nobody wrote down). With `DECISIONS_DIR`
   empty, keep every entry in `DECISIONS.agentk.md`. In case C with full
   entries in the index, offer the split (the `lineage` skill says how).
   Decision files are named `D-NNN-<short-name>.agentk.md`. If `LEDGER` is
   set: `KIT/templates/docs/EXPERIMENTS.md`, one row per experiment, saved
   at the `LEDGER` path (for example `experiments/EXPERIMENTS.agentk.md`).
5. **Case B**: `PLAN.agentk.md` from `KIT/templates/docs/PLAN.md`. Map only
   folders that exist; each unit gets its map when its folder is created.
6. **Command card**: `KIT/templates/docs/KIT.md`, saved as
   `KIT.agentk.md` at the root (`.agents/KIT.agentk.md` with `SHARE`
   `learning` or `none`, and in a team repo). Replace `<kit url>` with the kit's remote
   (`git -C KIT remote get-url origin`, as an https link). Never add it to
   the root `README.md`.
7. **Wiring** (team repo, `MAPS="beside"`). Run `sh .agents/kit/wire.sh --plan`
   and show me its list: for each folder and agent, what it will write and
   why, plus any limit. Apply it after one question (apply all, recommended
   / pick / skip / type). The cases it handles by itself:
   - Claude Code: a local `CLAUDE.local.md` per folder imports my
     `AGENTS.agentk.md`, and also the team's `AGENTS.md` where the folder has
     no `CLAUDE.md` (a `CLAUDE.local.md` stops Claude reading `AGENTS.md` by
     itself). My own lines in an existing `CLAUDE.local.md` stay.
   - Codex: a local `AGENTS.override.md` per folder holds the team's
     `AGENTS.md` first, then my map (Codex reads it instead of
     `AGENTS.md`). It refreshes after `git pull` and checkout (git hooks,
     when the kit may add them), at session start, on the Stop hook, and
     `check.sh` fails while it is stale.
   - Cursor: a local `.cursor/rules/agent-kit.mdc`.
   - A file git tracks (the team's `CLAUDE.local.md` or
     `AGENTS.override.md`) is never written: say that the agent cannot load
     my map in that folder.
   - Gemini / Antigravity: when `wire.sh` says `todo`, ask, then add
     `AGENTS.agentk.md` to `context.fileName` in my `~/.gemini/settings.json`
     (create the file, or append to the list, keeping my existing names).
     When it says `limit` (the team's `.gemini/settings.json` sets the list),
     say that Gemini cannot load my map here, and offer a note in
     `~/.gemini/GEMINI.md`: "In a repo with AGENTS.agentk.md files, read
     them after the team's AGENTS.md."
8. **Agent configs**: `.claude/settings.json` needs both the SessionStart and
   the Stop hook (the install says what to merge into an existing file). If
   more agents than Claude Code and Codex are used,
   tell me where each loads hooks and skills (check its docs) and add what
   is needed. Other agents rely on the pre-commit check.
9. **Commit-ready**: `git add` only what the share mode pushes. In a team
   repo, that is nothing of the kit's: `git status` must show no kit file. Never
   `git add -f` an ignored file. Do not commit unless I ask.

Rules for what you write: follow `KIT/templates/kit/writing-style.agentk.md`
(ASD-STE100, written for an intern); only paths that exist; only commands
you ran or found; never invent a decision's reason. Maps name paths in
backticks, and `check.sh` checks every one that looks like a path.

## Phase 5 — Verify and report

- `sh .agents/kit/check.sh` passes; show the output.
- `git add -A --dry-run` lists nothing the share mode keeps local
  (learning docs for `agent` and `none`; agent files for `learning` and
  `none`), and every file it pushes is staged.
- Ask me whether to write the learning docs now (all, overview only, or
  later), and if yes run the `learning-docs` skill.
- Run `docs-sync check` once and show its report.
- Show me how the work flows from now on, in five lines: maps load only for
  the folder an agent works in; a long task keeps its notes in a task file
  (`.agents/work/`, never committed); `wrap-up` ends every task; `catch-up`
  handles code written by hand; `explain-diff` goes into each pull request.
- In a team repo, show the per-agent report from
  `sh .agents/kit/wire.sh --plan`: each agent, whether it loads my map and
  the team's files, and any limit (with the fallback applied).
- Report: files created, config values, decisions recorded, open questions,
  and the agents whose hooks you could not verify.
