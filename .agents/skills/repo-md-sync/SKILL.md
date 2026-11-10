---
name: repo-md-sync
description: Bring the repo's own Markdown files (README.md, CONTRIBUTING.md, docs/*.md and the rest people wrote; never the kit's .agentk.md files or the agent files) up to date with the code, one file at a time and only after the user's yes - it lists the files, the user picks which to check, then approves each file's edits. Run it ONLY when the user names it ("repo-md-sync") or asks in their own words to update the README or the repo's normal docs; never offer, suggest or start it from another skill or on your own. Arguments - none (list all), stale (only files with code changes since), or one or more file paths.
---

# Repo Markdown sync

The repo's own Markdown files belong to the people here. Every other kit
skill only reports drift in them. This skill is the one way an agent edits
them, and only when the user starts it: never on your own, never from
another skill. Even then, it edits file by file after the user says yes
twice: once to the files, once to each file's edits. It never commits.

**Never touch** with this skill: kit docs (names ending in `DOC_SUFFIX`,
`.agentk.md`), `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `SKILL.md`, the local
wiring files, `<LEARNING_DIR>/`, `.agents/` and `.claude/`. The kit's other
skills keep those. If the user names one, say which skill owns it.

## 1. List the files

Run `sh .agents/skills/repo-md-sync/list.sh`. Each line is: file, last
updated, number of other files changed in its scope since then, scope. With
`stale`, keep the lines whose number is above 0. With file paths, keep
those.

Show a numbered table, files with changes first:

| # | File | Last updated | Code changed since | Scope |
|---|---|---|---|---|

If the user already ran `docs-sync` or `catch-up` in this session, mark the
files from its "Your docs" table: their drift is already known.

Ask: "Which files should I check? Numbers, `stale`, or `all`." Read nothing
before the answer.

## 2. Find what is now false

For each file the user picked, read it and the code changes in its scope
since its last update (`git log` and `git diff <its last commit> -- <scope>`).
List each claim that is now false or missing: commands, paths, settings and
env vars, defaults, versions, flags, routes, setup steps, and features the
code added or removed. A claim you cannot confirm is "unverified": leave it
as it is and say so.

## 3. Propose, file by file

For one file at a time, show:

| Line | Says now | Should say | Evidence |
|---|---|---|---|

Evidence is `file:line` in the code. Then ask with choices: apply all
(recommended), apply some (name the lines), change something, skip this
file. Go to the next file only after the answer.

How to write the edits:

- Change only the lines that are false or missing. Keep the file's voice,
  headings, format and line wrapping; do not restyle or reorder it.
- A new feature gets the smallest addition that fits the file's own
  structure (a table row, a bullet, one short section), never a new layout.
- A changelog or release notes: add an entry only when the user asks; never
  rewrite old entries.
- Never add the kit's marker lines (`<!-- agent-kit ... -->`) to these
  files. To pin a file's scope, offer it once and add it only after a yes.

## 4. Apply and report

Apply only the approved lines, with your edit tool. Then report each file
changed and each file skipped.

- **Never commit.** The edits are the user's own changes to commit.
- **In a team repo** (`MAPS="beside"`): these files go to the team in the
  user's pull request. Say so once, and keep each edit to what the code
  changed.
- Run `sh .agents/kit/check.sh` and show that it still passes.
