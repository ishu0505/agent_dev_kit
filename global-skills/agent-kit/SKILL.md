---
name: agent-kit
description: Set up, upgrade or check the agent context kit (AGENTS.md maps, DECISIONS.md lineage, repo skills, docs checks, local learning docs) in the current repository, for any language and OS. Use when the user says agent-kit, asks to set up agent context, AGENTS.md maps or docs checks in a repo, to start a new repo from a goal with this setup, or to upgrade a repo to a newer kit version. Arguments - setup (default), upgrade, check.
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
- **upgrade**: read `KIT/BOOTSTRAP.md` and follow it with `mode: upgrade`.
- **check**: run `sh .agents/kit/check.sh` in the repo and show the result.
  If `.agents/kit/` does not exist, say the kit is not installed here and
  offer `setup`. For a deeper check, run the repo's `docs-sync` skill in
  check mode.

All kit commands are POSIX `sh`. On Windows run them in Git Bash
(`sh`, `git` and the other tools come with Git for Windows). Never run
`install.sh` outside a git repository, and never commit unless the user
asks.
