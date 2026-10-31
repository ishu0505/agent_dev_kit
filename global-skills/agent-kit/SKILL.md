---
name: agent-kit
description: Set up, upgrade, clean up or check the agent context kit (AGENTS.md maps, DECISIONS.md lineage, repo skills, docs checks, local learning docs) in the current repository, for any language and OS. Use when the user says agent-kit, asks to set up agent context, AGENTS.md maps or docs checks in a repo, to start a new repo from a goal with this setup, or to upgrade a repo to a newer kit version, or see what waits (stale docs, code written without its docs). In a team repo it works beside the team's own AGENTS.md / CLAUDE.md and keeps everything local. Also sets up a multi-repo workspace (a folder holding several repos, such as a frontend and a backend). Arguments - setup (default), upgrade, cleanup, check, status, wire, unwire, workspace [init|add|scan|where|status].
---

# agent-kit

Find the kit folder (`KIT`, the folder holding `BOOTSTRAP.md` and
`install.sh`), using the first rule that works:

1. the environment variable `AGENT_KIT_HOME`;
2. the path written in the file `kit-path` next to this `SKILL.md` (present
   when the skill was copied, e.g. on Windows);
3. this file's real path with links resolved (`readlink -f` or `realpath`
   on this `SKILL.md`), two folders up;
4. `~/agent_dev_kit`.

If none holds `BOOTSTRAP.md`, ask the user where the kit is.

Then:

- **setup** (default): read `KIT/BOOTSTRAP.md` and follow it in the current
  repository. Phase 0 decides between a new project and an existing one.
  If the user named a share mode (`agent`, `all`, `learning`, `none`), use
  it; otherwise BOOTSTRAP's interview asks.
- **upgrade**: read `KIT/BOOTSTRAP.md` and follow it with `mode: upgrade`.
- **cleanup**: house cleaning only. Read `KIT/BOOTSTRAP.md` and run its
  phase 1b in the current repository (inventory, then one question per
  group, then apply only what the user approved). Install nothing.
- **check**: run `sh .agents/kit/check.sh` in the repo and show the result.
  If `.agents/kit/` does not exist, say the kit is not installed here and
  offer `setup`. For a deeper check, run the repo's `docs-sync` skill in
  check mode.
- **status**: read only. At a workspace root (`.agent-workspace/` exists),
  run `sh .agent-workspace/kit/workspace.sh status` instead. In a repo,
  show in one short list: the result of `sh .agents/kit/check.sh`; commits
  waiting for docs
  (`sh .agents/kit/queue.sh list`, offer `catch-up`); commits from other
  people since the docs were last checked (`sh .agents/kit/pulled.sh status`,
  offer `docs-sync` with scope `pulled`); stale learning docs
  (`$(git rev-parse --git-common-dir)/agent-kit/stale-learning`); docs
  whose code changed (`sh .agents/kit/stale.sh`); open task files
  (`sh .agents/kit/task.sh list`); and in a team repo the
  per-agent wiring (`sh .agents/kit/wire.sh --plan`). Change nothing.
- **wire** (team repo, `MAPS="beside"`): show `sh .agents/kit/wire.sh --plan`,
  then apply it after the user's yes (`sh .agents/kit/wire.sh`), including
  the Gemini step from `KIT/BOOTSTRAP.md` phase 4, step 7.
- **workspace** (a folder that holds several repos): with no further
  argument or `init`, read `KIT/WORKSPACE.md` and follow it in the current
  folder. `add <url|path>`, `scan`, `where` and `status` run
  `sh .agent-workspace/kit/workspace.sh <argument>` (from the workspace
  folder or any folder inside it). After `add` or `scan`, ask about each
  repo that waits for an answer, as `KIT/WORKSPACE.md` step 2 says.
- **setup** started in a folder that is not a git repo but holds repos:
  that is a workspace; offer `workspace` instead.
- **unwire**: `sh .agents/kit/wire.sh --remove` deletes every local file
  the kit made to connect the maps; the user's maps and the team's files
  stay.

All kit commands are POSIX `sh`. On Windows run them in Git Bash
(`sh`, `git` and the other tools come with Git for Windows). Never run
`install.sh` outside a git repository, never commit unless the user asks,
and never edit a Markdown file the kit did not write (the kit's files end
in `.agentk.md`, plus `AGENTS.md` and its pointer files). When you ask the
user something, give choices with your proposed answer first and "something
else: type your own" last (the kit's `templates/kit/writing-style.agentk.md`
says how).
