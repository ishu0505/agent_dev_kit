# agent_dev_kit

Give every coding agent a map of your repo, so it does not have to read all
the code. Keep the reason behind every decision. Keep the docs true without
remembering to check them. Teach people the system with local learning docs.

Works with Claude Code, Codex, Cursor, Muse, Antigravity and Gemini CLI, in a
repo of any language. The HTML guide is `guide/agent-context-kit.html`.

## What you get in a repo

| Part | Where | What it does |
|---|---|---|
| Maps | `AGENTS.md` in the root, top folders and every unit | Short pages: what is where, rules, how to run. Agents read these first |
| Pointer files | `CLAUDE.md` (and `GEMINI.md`) beside each map | Contain only `@AGENTS.md`, so every agent reads the same map |
| Lineage | `DECISIONS.md` (+ an optional experiment ledger) | Every decision with why, alternatives, evidence, and what would reverse it |
| Plan | `PLAN.md` (new projects) | The goal, the first milestone, the planned units |
| Skills | `.agents/skills/` (`.claude/skills` links here) | `lineage`, `scaffold`, `docs-sync`, `learning-docs` |
| Checks | `.agents/kit/check.sh` | Fails when a map is too long, names a missing path, a unit has no map, agent files are not in git, a hook is not portable, or learning docs are tracked |
| Automatic runs | `.githooks/pre-commit`, Stop hook | The checks run before every commit and after every agent turn that edits |
| Config | `.agents/agent-kit.conf` | Which folders are units, line limits, which pointer files |
| Learning docs | `learning_docs/` (git-ignored) | Plain-language explanations of the architecture, each unit and each flow, with quizzes. Never committed |

## Words used here

- **Unit**: a folder you work inside as a whole: a service, a package, an
  app, an experiment. Each unit gets a `README.md` and an `AGENTS.md`.
- **Map**: an `AGENTS.md` file. It points to detail; it does not hold it.
- **Skill**: a `SKILL.md` file of instructions an agent follows when you
  name it (`docs-sync check`).
- **Kit-owned file**: copied from this kit and replaced on upgrade.
  **Repo-owned file**: written for your repo and never overwritten.

## 1. One time on your computer

1. Clone the kit (any folder; the examples use `~/agent_dev_kit`):

   ```bash
   git clone <your agent_dev_kit repo URL> ~/agent_dev_kit
   ```

2. Give every agent the `agent-kit` skill:

   ```bash
   sh ~/agent_dev_kit/install-global.sh
   ```

   This links `global-skills/agent-kit` into `~/.claude/skills`,
   `~/.agents/skills` and `~/.gemini/antigravity/skills`. Links, not copies:
   a `git pull` in the kit updates every agent. Another agent folder:
   `AGENT_KIT_SKILL_DIRS="/path/to/skills" sh ~/agent_dev_kit/install-global.sh`.
   Remove: `sh ~/agent_dev_kit/install-global.sh --remove`.

3. Restart the agents that were open, so they load the new skill.

## 2. Start a new project from a goal

1. Make the folder a git repo:

   ```bash
   mkdir my-app && cd my-app && git init
   ```

2. Open your agent in that folder and type:

   - Claude Code: `/agent-kit setup`
   - Codex, Cursor, Muse, Antigravity: `agent-kit setup`
   - any other agent: `Read ~/agent_dev_kit/BOOTSTRAP.md and follow it.`

3. The agent sees an empty repo and says "case B, new project". Confirm.
4. Answer its questions one at a time: the goal, the first milestone, the
   stack, the planned units, the constraints. "Not decided yet" is a fine
   answer; it is recorded as an open question.
5. Read the file list it proposes and say OK.
6. It runs `install.sh`, then writes `PLAN.md`, `DECISIONS.md`, the root
   `AGENTS.md` and the README section, and runs the checks.
7. Review the changes, then commit them yourself (or ask the agent to).

Later, when you start a unit (say `services/api/`), ask for `scaffold`; the
unit gets its map, and `check.sh` stays green.

## 3. Add the kit to an existing project

1. Open your agent in the project root.
2. Type `agent-kit setup` (`/agent-kit setup` in Claude Code).
3. The agent reads the code and build files and reports, in under 30 lines,
   the units, commands and conventions it found. Confirm it says "case A".
4. Answer its questions; each one comes with a proposed answer you can
   accept.
5. Approve the file list. It installs the kit and writes the maps, the
   config and the first decisions.
6. It asks whether to write learning docs now. Say "overview only" for a
   quick start, or "all" for every unit and flow.
7. Review and commit. `learning_docs/` never shows up in `git status`.

## 4. Upgrade a repo to a newer kit

1. Update the kit: `cd ~/agent_dev_kit && git pull`.
2. In the repo, type `agent-kit upgrade`.
3. The agent compares `.agents/kit/VERSION` with the kit's `VERSION`, reads
   `CHANGELOG.md`, and runs `install.sh`. Kit-owned files are replaced; your
   config, maps, decisions and settings stay byte for byte.
4. It lists anything partial or missing and asks only about that.

A repo with an older hand-made setup (maps and checks, no `.agents/kit/`)
upgrades the same way; the agent also lists the old hooks and scripts the
kit replaces.

## 5. A teammate clones a repo that has the kit

Everything is in git except one setting. Run once in the clone:

```bash
git config core.hooksPath .githooks
```

Until then, `check.sh` reminds them.

## 6. Everyday use

| You want to | Type | Notes |
|---|---|---|
| Check fast, no AI | `sh .agents/kit/check.sh` | Seconds. Same as the pre-commit check |
| Know if code and docs agree | `docs-sync check` | Report only. Add a unit path, or `since main` for a branch |
| Make the docs match the code | `docs-sync fix` | Never changes code. Asks you when a change breaks a decision |
| Learn the system | `learning-docs` | First time: all, or overview only. Later: `learning-docs stale` |
| Record a decision or a result | `lineage` | It asks why, what else, evidence, what would reverse it |
| Add a service, package or experiment | `scaffold` | Creates its README, map and pointer files |
| See if the kit is installed | `agent-kit check` | Runs `check.sh`, or offers setup |

Claude Code wants a slash before a skill name (`/docs-sync check`).

### What runs by itself

- **Before every commit**: `.githooks/pre-commit` runs `check.sh`. A
  failure blocks the commit and prints the fix.
- **After every agent turn that edits** (Claude Code; Codex if its hooks are
  on): the Stop hook runs `check.sh`, and asks for the docs step when code
  changed but no doc did.
- **Nothing on a timer.** Run `docs-sync check` before merging a branch,
  after a large refactor, or after pulling other people's work.

## 7. Change the kit itself

1. Edit the templates (`templates/`), skills or scripts.
2. Run `sh tests/run.sh` (26 tests in throwaway repos; needs sh, git,
   python3).
3. Bump `VERSION`, add a `CHANGELOG.md` entry saying what an upgrading repo
   must do, and run `python3 guide/build.py`.
4. Commit and push. Repos pick it up with `agent-kit upgrade`.

## Limits

- The Stop hook reads Claude Code's transcript format. Codex's hook input is
  not verified; Cursor, Muse and Antigravity rely on the pre-commit check.
- The hook needs `python3`; without it the hook steps aside.
- On Windows use Git Bash, and `git config core.symlinks true` for the
  `.claude/skills` link.
- `docs-sync` and `learning-docs` are agent work; their quality depends on
  the agent reading the code. The checks are the part that is guaranteed.
