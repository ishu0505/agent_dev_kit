# Agent kit bootstrap

The setup prompt for any coding agent (Claude Code, Codex, Cursor,
Antigravity, Gemini CLI, Muse; app or CLI) in a repo of any language. Run the
agent inside the target repo and say:

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
5. **Learning docs**: local `learning_docs/` that teach people the system.
   Never committed.

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
  (old hooks, old check scripts) and propose removing it.

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

## Phase 3 — Propose

Show the file list with one line each, the config values, and a draft of
the root `AGENTS.md`. Wait for my approval.

## Phase 4 — Build

1. **Install** (all cases; this is also the upgrade):
   `sh KIT/install.sh .`
   It copies `.agents/kit/`, the four skills, `.githooks/pre-commit`,
   creates `.agents/agent-kit.conf`, `.claude/settings.json`,
   `.codex/hooks.json`, the `.claude/skills` link and the `learning_docs/`
   ignore line, and sets `core.hooksPath`. It never overwrites repo-owned
   files. Do everything it prints under "For the agent".
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
6. **Command card**: add `KIT/templates/docs/README-agent-context.md` as a
   section of the root `README.md`, with the kit's repo URL if I give one.
7. **Agent configs**: if more agents than Claude Code and Codex are used,
   tell me where each loads hooks and skills (check its docs) and add what
   is needed. Other agents rely on the pre-commit check.
8. **Commit-ready**: `git add` everything the kit created except
   `learning_docs/`. Do not commit unless I ask.

Rules for what you write: plain short sentences; only paths that exist;
only commands you ran or found; never invent a decision's reason.

## Phase 5 — Verify and report

- `sh .agents/kit/check.sh` passes; show the output.
- `git add -A --dry-run` does not list anything in `learning_docs/`.
- Ask me whether to write the learning docs now (all, overview only, or
  later), and if yes run the `learning-docs` skill.
- Run `docs-sync check` once and show its report.
- Report: files created, config values, decisions recorded, open questions,
  and the agents whose hooks you could not verify.
