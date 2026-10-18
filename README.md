# agent_dev_kit

Give every coding agent a map of your repo, so it does not have to read all
the code. Keep the reason behind every decision. Keep the docs true without
remembering to check them. Teach people the system with local learning docs.

Works with Claude Code, Codex, Cursor, Muse, Antigravity and Gemini CLI, in a
repo of any language, on macOS, Linux and Windows. The HTML guide is
`guide/agent-context-kit.html`.

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

## Operating systems

Every kit command is a POSIX `sh` script that needs only `git`, `grep`,
`awk`, `sed` and `cksum`. The Stop hook also needs Python 3.9 or newer. CI
tests every push on macOS, Ubuntu, Fedora and Windows.

| | macOS | Linux (Fedora, Ubuntu, ...) | Windows |
|---|---|---|---|
| Where you type commands | Terminal | Terminal | **Git Bash** (comes with Git for Windows) |
| Install first | nothing (git comes with Xcode tools) | `git`, `python3` (Fedora: `sudo dnf install git python3`) | [Git for Windows](https://git-scm.com/download/win) and Python 3 |
| `.claude/skills` | symlink | symlink | copy, chosen by the install (`SKILLS_LINK="copy"`); with Developer Mode and `git config --global core.symlinks true` it can be a symlink |
| Global `agent-kit` skill | symlink, follows `git pull` | symlink, follows `git pull` | copy: run `install-global.sh` again after each `git pull` |
| Python name the hook uses | `python3` | `python3` | `python3`, `python` or `py`, whichever exists |

The commands below are the same on all three. On Windows, `~` is your user
folder (`C:\Users\<you>`), and you type them in Git Bash, not PowerShell
or cmd. Line endings are handled for you: the kit adds `.gitattributes`
rules that keep its scripts LF on Windows.

A repo set up on one OS works on the others. A repo in copy mode works
everywhere; a repo in symlink mode cloned on Windows without symlink
support is caught by `check.sh`, which tells you how to switch to copy mode.

## 0. Your own copy of the kit (once)

The kit lives at `git@github.com:ishu0505/agent_dev_kit.git`. Someone else
using it: fork it, or clone it and push it to your own GitHub repo.

## 1. One time on your computer

1. Clone the kit (any folder; the examples use `~/agent_dev_kit`):

   ```bash
   git clone git@github.com:ishu0505/agent_dev_kit.git ~/agent_dev_kit
   ```

2. Give every agent the `agent-kit` skill:

   ```bash
   sh ~/agent_dev_kit/install-global.sh
   ```

   This links `global-skills/agent-kit` into `~/.claude/skills`,
   `~/.agents/skills` and `~/.gemini/antigravity/skills`. On macOS and Linux
   these are links, so a `git pull` in the kit updates every agent. On
   Windows it copies them and says so; run it again after each `git pull`. Another agent folder:
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

1. Update the kit: `cd ~/agent_dev_kit && git pull`. On Windows, then run
   `sh ~/agent_dev_kit/install-global.sh` again (the global skill is a copy).
2. In the repo, type `agent-kit upgrade`.
3. The agent compares `.agents/kit/VERSION` with the kit's `VERSION`, reads
   `CHANGELOG.md`, and runs `install.sh`. Kit-owned files are replaced; your
   config, maps, decisions and settings stay byte for byte.
4. It lists anything partial or missing and asks only about that.

5. Review the changes and commit.

## 4b. Move a repo with a hand-made setup onto the kit

For a repo that already has maps and checks but no `.agents/kit/` (for
example docu_nom_nom_69, with its pytest docs checks and its own Stop hook):

1. Open the agent in the repo and type `agent-kit upgrade`.
2. It installs the kit next to the old setup, then lists what the kit now
   does that the old setup also does: old check tests, old hook scripts,
   old hook entries in `.claude/settings.json` and `.codex/hooks.json`.
3. Say yes or no to removing each one. Keep a repo-specific check the kit
   does not replace; it can stay in the test suite.
4. It fills `.agents/agent-kit.conf` from the old setup (unit folders,
   ledger path, line limits) and runs `sh .agents/kit/check.sh`.
5. Review and commit.

## 5. A teammate clones a repo that has the kit

Everything is in git except one setting. Run once in the clone:

```bash
git config core.hooksPath .githooks
```

Until then, `check.sh` reminds them. On Windows they type it in Git Bash.
If the repo uses symlink mode and their Windows clone cannot make symlinks,
`check.sh` says so and gives the two commands that switch the repo to copy
mode.

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
| Edit a repo skill | edit it in `.agents/skills/` | In copy mode, then run `sh .agents/kit/sync-skills.sh` |

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
2. Run `sh tests/run.sh` (40 tests in throwaway repos; needs sh, git,
   Python 3). Pushing runs them on macOS, Ubuntu, Fedora and Windows
   (`.github/workflows/test.yml`).
3. Bump `VERSION`, add a `CHANGELOG.md` entry saying what an upgrading repo
   must do, and run `python3 guide/build.py`.
4. Commit and push. Repos pick it up with `agent-kit upgrade`.

## Limits

- The Stop hook reads Claude Code's transcript format. Codex's hook input is
  not verified; Cursor, Muse and Antigravity rely on the pre-commit check.
- The Stop hook needs Python 3.9+; without it the hook steps aside and the
  pre-commit check still runs.
- On Windows, the Stop hook depends on how each agent runs hook commands;
  only the pre-commit check is guaranteed there.
- `docs-sync` and `learning-docs` are agent work; their quality depends on
  the agent reading the code. The checks are the part that is guaranteed.
