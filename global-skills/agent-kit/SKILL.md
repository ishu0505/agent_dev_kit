---
name: agent-kit
description: Set up, upgrade or check the agent context kit (AGENTS.md maps, DECISIONS.md lineage, repo skills, docs checks, local learning docs) in the current repository, for any language. Use when the user says agent-kit, asks to set up agent context, AGENTS.md maps or docs checks in a repo, to start a new repo from a goal with this setup, or to upgrade a repo to a newer kit version. Arguments - setup (default), upgrade, check.
---

# agent-kit

This skill is a link into the user's `agent_dev_kit` folder. Find the kit:
resolve this file's real path (`readlink -f` / `realpath` on SKILL.md) and go
up two folders; that folder holds `BOOTSTRAP.md` and `install.sh`. Call it
`KIT`.

- **setup** (default): read `KIT/BOOTSTRAP.md` and follow it in the current
  repository. Phase 0 decides between a new project and an existing one.
- **upgrade**: read `KIT/BOOTSTRAP.md` and follow it with `mode: upgrade`.
- **check**: run `sh .agents/kit/check.sh` in the repo and show the result.
  If `.agents/kit/` does not exist, say the kit is not installed here and
  offer `setup`. For a deeper check, run the repo's `docs-sync` skill in
  check mode.

Never run `install.sh` outside a git repository, and never commit unless the
user asks.
