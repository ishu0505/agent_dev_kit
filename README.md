# agent_dev_kit

Give every coding agent a map of your repo, so it does not have to read all
the code. Keep the reason behind every decision. Keep the docs true without
remembering to check them, and without slowing the agent down. Keep people
in the loop: code written by hand gets explained and documented with their
approval, and every pull request explains itself with a short quiz. Teach
people the system with learning docs.

Works with Claude Code, Codex, Cursor, Muse, Antigravity and Gemini CLI, in a
repo of any language, on macOS, Linux and Windows. The HTML guide is
`guide/agent-context-kit.html`.

## What you get in a repo

**Your Markdown files stay yours.** Every Markdown file the kit writes ends
in `.agentk.md` (`README.agentk.md`, `DECISIONS.agentk.md`,
`KIT.agentk.md`), so you can see at a glance what came from the kit. The kit
never edits, renames or deletes your other Markdown files, such as
`README.md` or `docs/*.md`: agents read them, and `docs-sync` reports when
one no longer matches the code, with a sentence you can paste in. Four
names keep no suffix, because agents load them only by these exact names:
`AGENTS.md`, `CLAUDE.md`, `GEMINI.md` and `SKILL.md`. The ending is
`DOC_SUFFIX` in `.agents/agent-kit.conf`.

| Part | Where | What it does |
|---|---|---|
| Maps | `AGENTS.md` in the root, and in each unit past a size threshold | Short pages: what is where, rules, how to run. An agent loads the root map and the maps on the path to the folder it works in, nothing else |
| Detail docs | `README.agentk.md` beside each unit map | The detail a map points to. Your own `README.md` in the same folder is linked, never changed |
| Command card | `KIT.agentk.md` at the root | How to use the kit in this repo. Your root `README.md` is not changed |
| Pointer files | `CLAUDE.md` (and `GEMINI.md`) beside each map | Contain only `@AGENTS.md`, so every agent reads the same map |
| Lineage | `DECISIONS.agentk.md` (an index) + one file per decision in `docs/decisions/` (+ an optional experiment ledger) | Every decision with why, alternatives, evidence, and what would reverse it |
| Plan | `PLAN.agentk.md` (new projects) | The goal, the first milestone, the planned units |
| Skills | `.agents/skills/` (`.claude/skills` links here) | `lineage`, `scaffold`, `docs-sync`, `learning-docs`, `wrap-up`, `catch-up`, `explain-diff` |
| Checks | `.agents/kit/check.sh` | Fails when a map is too long or names a missing path (in a table or in prose), a big unit has no map, a decision is missing from the index, agent files are not in git, a hook is not portable, or learning docs are tracked. Optional: env var names, and the map's own run commands |
| Automatic runs | `.githooks/pre-commit`, `post-commit`, SessionStart and Stop hooks, CI | Before a commit: only what the commit breaks blocks. After a commit: code without its docs is queued for `catch-up`. After an agent turn: checks only what the turn changed. In CI: the same checks, so a skipped hook cannot let drift in |
| Writing style | `.agents/kit/writing-style.agentk.md` | ASD-STE100 Simplified Technical English, written for an intern; every skill that writes follows it |
| Config | `.agents/agent-kit.conf` | Which folders are units, map thresholds, line limits, pointer files, interface files |
| Learning docs | `learning_docs/` | Plain-language explanations of the architecture, each unit and each flow, with quizzes. Refreshed at the end of a task. Local or pushed, by share mode |

## Share modes: what reaches GitHub

You pick one when you set a repo up. The agent asks.

| Mode | Agent files | Learning docs | Use it when |
|---|---|---|---|
| `agent` (default) | pushed | local | The team shares the agent context; learning docs are yours |
| `all` | pushed | pushed | Everyone, including new people, should get both |
| `learning` | local | pushed | You want people to learn the system, but keep your agent setup private |
| `none` | local | local | Nothing about agents or learning docs may reach the remote |

**Agent files** are every `AGENTS.md` and pointer file (`CLAUDE.md`),
every file ending in `.agentk.md` outside the learning docs, and the
folders `.agents/`, `.claude/`, `.codex/`, `.githooks/`.

How it works:

- A pushed file is a normal tracked file.
- A local file is ignored through `.git/info/exclude`. That file sits inside
  `.git/` and is never committed, so not even the ignore rule shows up on
  GitHub. In `learning` and `none` mode the kit also keeps its line-ending
  rules in `.git/info/attributes` instead of `.gitattributes`.
- `check.sh` guards it before every commit: in a local mode it blocks a
  commit that tracks or stages an agent file (for example after
  `git add -f`). In `agent` mode it does the same for learning docs.
- Local files exist only on that machine. A fresh clone, another computer
  or a teammate does not get them; back them up yourself if they matter.

Change the mode of a repo later:

```bash
sh ~/agent_dev_kit/install.sh --share none .
```

The install rewrites the rules and, when files that are now local are still
tracked, prints the `git rm -r --cached ...` command that stops tracking
them (the files stay on disk). Run it, then commit.

When teammates committed those files, the install prints a **WARNING**
instead: the commit that stops tracking them deletes them for everyone who
pulls it. Use `--share agent` or `all` if the team should keep them; add
`--confirm-untrack` only when the team agreed.

## Words used here

- **Unit**: a folder you work inside as a whole: a service, a package, an
  app, an experiment. A unit with at least `MAP_MIN_FILES` code files
  (default 15) or `MAP_MIN_LINES` code lines (default 1500) gets a
  `README.agentk.md` and an `AGENTS.md`; a smaller one is a row in a map.
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
   `~/.agents/skills`, `~/.gemini/config/skills` (agy CLI) and
   `~/.gemini/antigravity/skills` (Antigravity IDE). On macOS and Linux
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

   - Claude Code or agy: `/agent-kit setup`
   - Codex: `$agent-kit setup`
   - Codex, Cursor, Muse, Antigravity: `agent-kit setup`
   - any other agent: `Read ~/agent_dev_kit/BOOTSTRAP.md and follow it.`

3. The agent sees an empty repo and says "case B, new project". Confirm.
4. Answer its questions, one at a time: the goal, the first milestone, the
   stack, the planned parts, the constraints, and what may go to GitHub
   (the **share mode**; see "Share modes"). Each question is in plain words
   and comes with choices, so you mostly pick a number:

   ```
   Which coding agents do you use here?
     1. Claude Code only (recommended: I found .claude/ and no other agent)
     2. Claude Code and Codex
     3. Claude Code, plus Gemini CLI or Antigravity
     4. Something else: type your own answer
   ```

   Claude Code shows these as a choice box; Codex, Gemini CLI and other
   agents print a numbered list. The last choice is always your own words.
   "Not decided yet" is recorded as an open question. The first question
   also offers "use your proposed answers for everything", which jumps to
   the summary. To skip a question, say it up front:
   `/agent-kit setup, share mode none`.
5. Read the file list it proposes and say OK.
6. It runs `install.sh`, then writes `PLAN.agentk.md`,
   `DECISIONS.agentk.md`, the root `AGENTS.md` and `KIT.agentk.md`, and runs
   the checks.
7. Review the changes, then commit them yourself (or ask the agent to).

Later, when you start a unit (say `services/api/`), ask for `scaffold`; the
unit gets its map, and `check.sh` stays green.

## 3. Add the kit to an existing project

1. Open your agent in the project root.
2. Type `agent-kit setup` (`/agent-kit setup` in Claude Code).
3. The agent reads the code and build files and reports, in under 30 lines,
   the units, commands and conventions it found. Confirm it says "case A".
4. Answer its questions: each has the agent's proposed answer first, a few
   other choices, and "type your own" last. One is the share mode (see
   "Share modes"); one confirms that the kit names its own files
   `*.agentk.md` and leaves your `README.md` files alone.
5. Approve the file list and the settings table (each setting with your
   answer and what it means in plain words). It installs the kit and
   writes the maps, the kit's detail docs, the config and the first
   decisions. None of your existing files change.
6. It asks whether to write learning docs now. Say "overview only" for a
   quick start, or "all" for every unit and flow.
7. Review and commit. Files the share mode keeps local never show up in
   `git status`.

## 4. Upgrade a repo to a newer kit

1. Update the kit: `cd ~/agent_dev_kit && git pull`. On Windows, then run
   `sh ~/agent_dev_kit/install-global.sh` again (the global skill is a copy).
2. In the repo, type `agent-kit upgrade`.
3. It runs house cleaning first (see "House cleaning"), then compares
   `.agents/kit/VERSION` with the kit's `VERSION`, reads `CHANGELOG.md`, and
   runs `install.sh`. Your config, maps, decisions and settings stay byte
   for byte. Skills are handled as in "Your skills are safe".
4. It lists anything partial or missing and asks only about that.
5. **From kit 0.5 or older**, the kit's files still have plain names
   (`DECISIONS.md`, a unit's `README.md`). Nothing breaks: the old names
   keep working. The agent lists the kit's files, asks you which unit
   `README.md` files the kit wrote and which are yours, and offers to rename
   the kit's files to `*.agentk.md` (with `git mv`, so history follows).
   Say no, and it keeps the old names.
6. Review the changes and commit.

## Your skills are safe

The kit brings seven skills: `lineage`, `scaffold`, `docs-sync`,
`learning-docs`, `wrap-up`, `catch-up`, `explain-diff`. A skill with any
other name is never touched. For these, `install.sh` records a fingerprint of each one it installs
(`.agents/kit/skills.sum`) and on every later run:

| The skill in your repo | What the install does |
|---|---|
| is missing, or exactly the kit's version | installs the kit's version |
| you never edited it | replaces it with the new kit version |
| you edited it, and the kit has no newer version | keeps yours |
| you edited it, and the kit has a newer version | keeps yours; puts the new kit version in `.git/agent-kit/incoming/<skill>/`; the agent asks you whether to merge it in |
| it was your own before the kit (same name, different content) | keeps yours, and the agent asks whether it is your own |
| it is listed in `OWN_SKILLS` | never touched, no update offered |

Mark a skill as yours in `.agents/agent-kit.conf`:

```sh
OWN_SKILLS="lineage scaffold"
```

The kit offers each update once. `.git/agent-kit/incoming/` is inside
`.git`, so it is never committed and agents do not load it as a skill.

## House cleaning

Before setting the kit up in an existing project, and before every upgrade,
the agent tidies the repo with you. Run it on its own any time:
`agent-kit cleanup` (`/agent-kit cleanup` in Claude Code and agy,
`$agent-kit cleanup` in Codex).

1. **Inventory.** `inventory.sh` lists every agent and doc file in groups:
   maps and pointer files, other agents' rule files (`.cursorrules`,
   `.cursor/rules`, Copilot), skills, commands, hooks and settings,
   decisions and plans, learning docs, other Markdown. For each: tracked or
   not, last commit, size, and notes such as "not changed in 200 days",
   "same content as X", "same name as a kit skill". It changes nothing.
   You can run it yourself:

   ```bash
   sh ~/agent_dev_kit/templates/kit/inventory.sh .
   ```

2. **Proposal.** For each file the agent proposes **keep**, **merge** (into
   `AGENTS.md` or `DECISIONS.agentk.md`, then remove; only for agent files,
   never your docs), **own** (a skill that goes
   into `OWN_SKILLS`), **remove**, or **leave alone** (data and generated
   output, one answer per folder), with a reason.
3. **One group at a time.** You answer each group; you can change any
   action. No existing skill is touched without your yes.
4. **Apply.** Only what you approved. Tracked files go with `git rm`, so
   they can come back from history. Nothing is committed.
5. **Record.** One decision lists what was kept, merged and
   removed, and why.

## 4b. Move a repo with a hand-made setup onto the kit

For a repo that already has maps and checks but no `.agents/kit/` (for
example one with its own pytest docs checks and its own Stop hook):

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

(If the repo uses pre-commit, lefthook or husky, their own install step
does it instead.)

Until then, `check.sh` reminds them. On Windows they type it in Git Bash.
If the repo uses symlink mode and their Windows clone cannot make symlinks,
`check.sh` says so and gives the two commands that switch the repo to copy
mode.

## 6. Everyday use

| You want to | Type | Notes |
|---|---|---|
| Check fast, no AI | `sh .agents/kit/check.sh` | Seconds. The pre-commit runs it with `--staged`, which blocks only what the commit breaks |
| Finish a task | `wrap-up` | Checks, docs of this branch, asks before refreshing stale learning docs, writes the PR section |
| Document code you wrote yourself | `catch-up` | Explains each change, asks what it is for, proposes docs and docstrings; applies only what you approve |
| Understand a branch or PR | `explain-diff` | Background, intuition, code walkthrough, five-question quiz. `--post` puts it in the PR |
| Know if code and docs agree | `docs-sync check` | Report only. Reads only docs whose anchors changed (`since main` by default) |
| See what may be stale | `sh .agents/kit/stale.sh` | No AI. Each doc whose code changed since the doc did |
| Make the docs match the code | `docs-sync fix` | Never changes code. Asks you when a change breaks a decision |
| Learn the system | `learning-docs` | First time: all, or overview only. Later: `learning-docs stale` |
| Record a decision or a result | `lineage` | It asks why, what else, evidence, what would reverse it |
| Add a service, package or experiment | `scaffold` | Creates its README, map and pointer files |
| See if the kit is installed | `agent-kit check` | Runs `check.sh`, or offers setup |
| See what waits | `agent-kit status` | Checks, the catch-up queue, stale docs |
| Commit with no docs needed | put `[no-docs]` in the message | The commit stays out of the catch-up queue |
| Tidy agent and doc files | `agent-kit cleanup` | Inventory, then one question per group; nothing removed without your yes |
| Edit a repo skill | edit it in `.agents/skills/` | In copy mode, then run `sh .agents/kit/sync-skills.sh` |

### How to see and call skills in each agent

Start a new session after installing or changing a skill: agents read
skills when a session starts.

| Agent | List skills | Call a skill |
|---|---|---|
| Claude Code (CLI and app) | type `/` (skills show in the menu) or `/skills` | `/agent-kit setup`, `/docs-sync check` |
| Codex CLI | `/skills` | type `$` and pick it: `$agent-kit setup`, `$docs-sync check` (skills are not in the `/` menu) |
| Antigravity CLI (`agy`) | `/skills` inside a session | `/agent-kit setup`, or name it in plain words |
| Cursor, Muse | the skills panel / `muse skills list` | name it in plain words: `agent-kit setup` |

Every agent also picks a skill by itself when your request matches its
description ("set up the agent kit in this repo"). If a skill does not show
up, check the link: `ls -L ~/.claude/skills/agent-kit`.

### What runs by itself

- **Before every commit**: `.githooks/pre-commit` runs `check.sh --staged`.
  Only problems this commit causes block it (a map it edits, a path it
  deletes, a unit it adds code to); someone else's broken map does not, so
  nobody needs `--no-verify`. A failure prints the fix.
- **After every commit**: `.githooks/post-commit` queues a commit that
  changed code but not the docs above that code (usually code written by
  hand). The next agent session says so in one line, and `catch-up` works
  through the queue with you. It never blocks.
- **When an agent session starts** (Claude Code): one line about the queue
  and stale learning docs, only when there is something.
- **After every agent turn** (Claude Code; Codex if its hooks are on): the
  Stop hook compares `git status` with the last turn. Nothing changed:
  nothing runs. Something changed: `check.sh` for those files only, and a
  docs reminder only when a file a map names changed, a file was added to
  or removed from a folder a map names, or an interface file changed
  (`INTERFACE_GLOBS`). It asks once per file, and editing the README or map
  above the file satisfies it. Learning docs whose code changed are noted
  for `wrap-up`, never blocking.
- **In CI** (`install.sh --ci`): `check.sh --ci`, and on a pull request
  `--since <base>`, so the branch is judged on its own changes.
- **At the end of a task**: the root map tells the agent to run `wrap-up`.

## 7. Change the kit itself

1. Edit the templates (`templates/`), skills or scripts.
2. Run `sh tests/run.sh` (114 tests in throwaway repos; needs sh, git,
   Python 3). Pushing runs them on macOS, Ubuntu, Fedora and Windows
   (`.github/workflows/test.yml`).
3. Bump `VERSION`, add a `CHANGELOG.md` entry saying what an upgrading repo
   must do, and run `python3 guide/build.py`.
4. Commit and push. Repos pick it up with `agent-kit upgrade`.

## Limits

- The Stop hook finds changes with git, so it covers shell edits and
  subagents. The SessionStart hook is set up for Claude Code only; without
  it, the first stop of a session treats files that were already changed as
  changed by the agent. Codex's hook input is not verified; Cursor, Muse and
  Antigravity rely on the pre-commit check and CI.
- Paths in prose are checked when they look like paths (a `/`, or a known
  file extension). End a line with `<!-- agent-kit: skip -->` to leave it
  out. Behaviour (defaults, flows) is checked by `docs-sync`, which is
  agent work.
- The Stop hook needs Python 3.9+; without it the hook steps aside and the
  pre-commit check still runs.
- On Windows, the Stop hook depends on how each agent runs hook commands;
  only the pre-commit check is guaranteed there.
- `docs-sync` and `learning-docs` are agent work; their quality depends on
  the agent reading the code. The checks are the part that is guaranteed.
