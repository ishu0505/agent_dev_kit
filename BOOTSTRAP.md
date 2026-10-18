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
   all the code. `CLAUDE.md` / `GEMINI.md` only import them.
2. **Lineage**: `DECISIONS.md`, the reason behind every choice; an optional
   experiment ledger.
3. **Skills** in `.agents/skills/`: `lineage`, `scaffold`, `docs-sync`,
   `learning-docs`.
4. **Checks**: `.agents/kit/check.sh`, run on every commit and after every
   editing turn, so the docs stay true.
5. **Learning docs**: `learning_docs/` that teach people the system.
6. **A share mode** (`SHARE`): which of these reach the remote repo.

The scripts and skills are ready-made in `KIT/templates/`; copy them, do not
rewrite them. Your work is the repo-specific part: the config, the maps,
the decisions and the plan. Work in the phases below, do not skip ahead, and
write nothing before phase 3 is approved (phase 4 starts with the install).

## Phase 0 — Which case

Look at the repo, then tell me which case you see and wait for my OK:

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

Cases A and C go through **phase 1b, house cleaning**, after exploring and
before anything is installed. Case B has nothing to clean.

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

Report in under 30 lines: units, commands, conventions, existing docs,
unclear points.

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
     decisions into `DECISIONS.md`, other agents' rule files into the maps
     so every agent reads the same rules), then remove it;
   - **own**: a skill the repo keeps as its own, added to `OWN_SKILLS` in
     `.agents/agent-kit.conf`. Propose this for every repo skill that has a
     kit skill's name but different content;
   - **remove**: stale, duplicate, or replaced by the kit;
   - **leave alone**: not about agents or docs (data, generated output,
     reports). Say so once for a whole folder instead of file by file.
3. **Ask one group at a time.** Show the group as a table (path, action,
   reason) and wait for my answer before the next group. I may change any
   action. Never touch an existing skill without my yes.
4. **Apply** only what I approved. Remove tracked files with `git rm`
   (recoverable from history), untracked ones with `rm` after I confirm
   that path. Write merged content in the target file before removing the
   source. Do not commit.
5. **Record** the cleanup as one `DECISIONS.md` entry (with the `lineage`
   skill after phase 4): what was kept, merged, owned and removed, and why.

Run this phase again whenever I ask for `agent-kit cleanup`.

## Phase 2 — Interview

Ask **one question at a time**. Propose an answer from what you found; I
confirm or correct it. Record "not decided yet" as open.

New project only (case B), first:

- the goal in one paragraph: who uses it, the problem, what "working" means;
- the first milestone, and what is out of scope;
- language, framework and storage (if undecided, propose options with one
  reason each; the choice becomes a decision);
- the planned units and how they talk (HTTP, queue, events, files, calls);
- hard constraints: budget, latency, privacy, platforms, licences.

Every case:

1. What the repo is for, in one line, and the **priorities in order** when
   they conflict.
2. Which agents will work here (sets `POINTER_FILES`: `CLAUDE.md`, plus
   `GEMINI.md` for Gemini CLI / Antigravity).
3. Which folders are units (`UNITS`) and which folders hold units
   (`UNIT_PARENTS`).
4. Code conventions to enforce.
5. **Invariants**: rules a change must never break.
6. The **check** command a change must pass.
7. Decisions already made, and where their reasons are written.
8. Experiments or benchmarks that decide what ships, and where (`LEDGER`).
9. Learning docs: who reads them, which flows matter most (API requests,
   queue / worker jobs, pipelines, CLI), which units first.
10. Folders agents must never edit (generated, vendored, data).
11. **Share mode**: what may reach the remote repo. Explain the four
    choices and recommend one:
    - `agent` (default): agent files pushed, learning docs local;
    - `all`: agent files and learning docs pushed;
    - `learning`: learning docs pushed, agent files local;
    - `none`: nothing pushed, everything stays on this machine.
    "Agent files" are every `AGENTS.md` and pointer file, `DECISIONS.md`,
    `PLAN.md`, the ledger, `.agents/`, `.claude/`, `.codex/`, `.githooks/`.
    Local files are ignored through `.git/info/exclude`, which is never
    committed, so not even an ignore rule shows up in the remote. Local
    files exist only on this machine: a fresh clone or another computer
    does not get them.
12. Operating systems the team uses. Windows without symlink support means
    `SKILLS_LINK="copy"`; the install also switches to it by itself when a
    symlink cannot be made.

## Phase 3 — Propose

Show the file list with one line each, the config values, and a draft of
the root `AGENTS.md`. Wait for my approval.

## Phase 4 — Build

1. **Install** (all cases; this is also the upgrade):
   `sh KIT/install.sh --share <mode> .` (on Windows, run every kit command
   in Git Bash). In case C, leave out `--share` to keep the repo's mode;
   pass it only when I ask to change the mode.
   It copies `.agents/kit/`, the four skills, `.githooks/pre-commit`,
   creates `.agents/agent-kit.conf`, `.claude/settings.json`,
   `.codex/hooks.json`, `.claude/skills` (a link, or a copy where symlinks
   fail), writes the ignore and LF rules for the share mode (shared rules in
   `.gitignore` / `.gitattributes`, local ones in `.git/info/`), sets
   `core.hooksPath`, and, when agent files are shared, stages the scripts
   as executable. It never overwrites repo-owned files. Kit skills are
   replaced only if the repo never edited them (fingerprints in
   `.agents/kit/skills.sum`); skills in `OWN_SKILLS` are never touched. Do
   everything it prints under "For the agent". For each skill it kept
   because the repo edited it or had its own, ask me: is it the repo's own
   (add it to `OWN_SKILLS`), or should it take the kit's update (merge the
   new version from `.git/agent-kit/incoming/<skill>/` into it, keeping the
   repo's additions; `KIT/CHANGELOG.md` says what changed)? The kit offers
   each update once: the next upgrade keeps the merged skill.
2. **Config**: fill `.agents/agent-kit.conf` from the interview.
3. **Maps**: the root `AGENTS.md` from `KIT/templates/docs/AGENTS.root.md`
   (at most `TOP_MAP_MAX` lines), then one map per first-level folder that
   needs one, then each unit with the `scaffold` skill
   (`KIT/templates/docs/AGENTS.unit.md`, at most `UNIT_MAP_MAX` lines). One
   pointer file per `POINTER_FILES` entry beside every map, containing only
   `@AGENTS.md`. Map only paths that exist.
4. **Lineage**: `DECISIONS.md` from `KIT/templates/docs/DECISIONS.md`,
   seeded with the decisions from the interview (write "not recorded" for a
   reason nobody wrote down). If `LEDGER` is set:
   `KIT/templates/docs/EXPERIMENTS.md`, one row per experiment.
5. **Case B**: `PLAN.md` from `KIT/templates/docs/PLAN.md`. Map only
   folders that exist; each unit gets its map when its folder is created.
6. **Command card**: `KIT/templates/docs/README-agent-context.md`. With
   `SHARE` `agent` or `all`, add it as a section of the root `README.md`.
   With `learning` or `none`, write it to `.agents/README.md` instead and
   leave the committed README untouched.
7. **Agent configs**: if more agents than Claude Code and Codex are used,
   tell me where each loads hooks and skills (check its docs) and add what
   is needed. Other agents rely on the pre-commit check.
8. **Commit-ready**: `git add` only what the share mode pushes. Never
   `git add -f` an ignored file. Do not commit unless I ask.

Rules for what you write: plain short sentences; only paths that exist;
only commands you ran or found; never invent a decision's reason.

## Phase 5 — Verify and report

- `sh .agents/kit/check.sh` passes; show the output.
- `git add -A --dry-run` lists nothing the share mode keeps local
  (learning docs for `agent` and `none`; agent files for `learning` and
  `none`), and every file it pushes is staged.
- Ask me whether to write the learning docs now (all, overview only, or
  later), and if yes run the `learning-docs` skill.
- Run `docs-sync check` once and show its report.
- Report: files created, config values, decisions recorded, open questions,
  and the agents whose hooks you could not verify.
