# Agent kit: multi-repo workspace

The setup prompt for a folder that holds several git repos side by side
(`frontend/`, `backend/`, ...). Run the agent **in that folder** and say:

    Read <path to agent_dev_kit>/WORKSPACE.md and follow it.

Or use the global skill: `agent-kit workspace` (Claude Code:
`/agent-kit workspace`).

---

`KIT` below means the folder that contains this file. `WS` means
`sh .agent-workspace/kit/workspace.sh` (after step 1). Ask questions the
way `KIT/templates/kit/writing-style.agentk.md` says: one at a time, your
proposal first, "something else: type your own" last.

## What the workspace gets

- `WORKSPACE.agentk.md`: the workspace map. It holds a table of the repos
  (role, kit, the file to read first), the contracts between them, and the
  rules.
- `CLAUDE.md` and `AGENTS.md` at the root: short pointers to that map. Claude
  Code also reads them when it starts inside a repo here, because it reads
  `CLAUDE.md` in every parent folder. Codex reads the root files only when it
  starts here. Inside a repo with the kit, `.agents/kit/wire.sh` gives Codex a
  local pointer.
- `.agent-workspace/`: the scripts, `workspace.conf` (`LINKS` between
  repos), and light maps for repos without the kit.
- Hooks at the root (`.claude/settings.json`, `.codex/hooks.json`): when an
  agent works from this folder, every repo with the kit is checked after
  each turn. A change to a `LINKS` provider names the consumer.

Nothing is written inside a repo except the kit install that the user
approves. A "never" answer is a note in that repo's `.git` folder, which is
never committed or pushed. **No team file is touched, and nothing reaches a
remote.**

## 1. Init

Run `sh KIT/templates/workspace/workspace.sh init` (add `--name <name>` if
the user gave one). If the folder is itself a git repo, stop and ask: is
this repo the workspace (then add `--meta`), or should the workspace be one
folder up? Show the scan table that init prints.

## 2. One question per repo without an answer

For each repo that `init` lists under "Waiting for an answer", ask:

```
backend/ has no agent kit. Install it?
  1. Install, beside the team's files (recommended: <hint from the scan, e.g. 6 authors>)
  2. Install as my own repo (the kit owns AGENTS.md)
  3. Not now (ask again next time)
  4. Never (a note in backend/.git; nothing else changes)
  5. Something else: type your own answer
```

Recommend option 1 when the scan hint is `team`, and option 2 when it is
`personal`.

- **Install**: run `sh KIT/install.sh --maps beside <dir>` (or without
  `--maps` for own). Then say that the full setup of that repo (its maps and
  decisions) is `agent-kit setup` started inside it, and offer it for later.
  Do not run it now unless the user asks.
- **Not now**: write nothing.
- **Never**: `WS decline <dir>`.

## 3. Light maps for repos without the kit

For each repo with "declined" or "none", read its README, its own
`AGENTS.md` / `CLAUDE.md`, its build files and its entry points. **Write
nothing inside it.** Then write `.agent-workspace/maps/<dir>.agentk.md`
(use `__` for a `/` in `<dir>`), at most 40 lines:

```
---
repo: <dir>
source_commit: <git -C <dir> rev-parse HEAD>
---
# <dir> (light map; the repo has no agent kit)

<What it is, in two sentences.>

| Path | What |
|---|---|
| ... | ... |

## Run
## Contracts with other repos here
```

`WS scan` reports a light map that has fallen behind the repo. Refresh it
then.

## 4. Roles and contracts

Propose a one-line role for each repo, from its README and code (for
example, "the REST API for the web app"). Write the roles in the Role column
of the table; `WS scan` keeps them. Then look for contracts between repos:
an OpenAPI or GraphQL schema, `.proto` files, a shared types package, env
vars that one repo sets and another reads, events. Propose each one as a
line in "Contracts between repos" and as a `LINKS` entry
(`provider:path>consumer:folder`). Write what the user approves.

## 5. Report

Show the final `WS scan` table and say how to use the workspace:

- Start the agent in this folder for work across repos. Start it inside one
  repo for work there only.
- `agent-kit workspace` (or `WS scan`) after you clone or copy in a new repo.
- `WS add <url|path>` to bring a repo in. A repo that is already in another
  workspace becomes a git worktree: one `.git`, its own folder. A branch can
  be checked out in only one worktree at a time.
- `WS where` (inside a repo) lists every workspace that holds it.
- Copy-pasted repos work. Their `.git` comes with them, including the
  kit's notes (a "never" answer, the catch-up queue). Symlinked repos are
  not supported: the wrong workspace map would load.

## Upgrade

Run `sh KIT/templates/workspace/workspace.sh init` again in the workspace.
It replaces `.agent-workspace/kit/` and keeps your files
(`WORKSPACE.agentk.md`, `workspace.conf`, the light maps, the pointers).
