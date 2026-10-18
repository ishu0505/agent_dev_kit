---
name: docs-sync
description: Check whether the code and the docs agents and humans read (AGENTS.md maps, READMEs, DECISIONS.md invariants, learning docs) still agree, and optionally make the docs match the code. Use when the user asks "are the docs in sync", before merging a branch, after a refactor or a pull of other people's changes, or when an agent seems misled by a doc. Modes - check (report only) or fix. Scope - all, a unit path, or since <git ref>.
---

# Docs sync

`.agents/kit/check.sh` catches mechanical drift: a long map, a dead path, a
missing file. It cannot see that a README names an old default or that a
learning doc describes a removed step. This skill does that reading.

**Arguments.** Mode: `check` (default; change nothing) or `fix`. Scope:
`all` (default), a unit path, or `since <ref>` (e.g. `since main`: only
what this branch changed). Settings come from `.agents/agent-kit.conf`.

## 1. Run the checks

Run `sh .agents/kit/check.sh`. Every failure goes into the report.

## 2. Find the candidates (git only, no reading yet)

Within the scope:

- each `AGENTS.md` and `README.md` whose folder has code changes newer than
  the doc's own last commit:
  `c=$(git log -1 --format=%H -- <doc>)`, then
  `git diff --stat "$c" -- <folder>`, plus uncommitted changes from
  `git status --short -- <folder>`;
- each learning doc (in `LEARNING_DIR`) whose `source_paths` changed since
  its `source_commit`: `git diff --stat <source_commit> -- <source_paths>`;
- each `accepted` entry in `DECISIONS.md` and each invariant in a map that
  names a file, function, env var or command.

With scope `since <ref>`, start from `git diff --name-only <ref>...HEAD`
and keep only docs covering those files.

## 3. Read and compare

For each candidate, read the doc and the code diff since the doc's commit.
List every claim that is now false:

- paths, commands and scripts (does the file or target exist?);
- env vars and settings (grep the code for each name the doc gives);
- defaults, limits, ports, versions;
- interfaces: function names, routes, message fields, CLI flags;
- flow steps in learning docs (does each named function still do that?);
- invariants: search for a violation (e.g. a provider SDK imported outside
  the one module allowed to call it).

A claim you cannot confirm or refute is "unverified", not "wrong".

## 4. Report

One table, grouped by unit:

| Doc | Claim | What the code does | Evidence | Proposed fix |
|---|---|---|---|---|

Evidence is `file:line`. End with: docs checked, docs in sync, docs with
drift, unverified claims. In `check` mode, stop here and change nothing.

## 5. Fix (`fix` mode only)

- **Docs follow the code.** Never change code to match a doc.
- A change that breaks an invariant or an `accepted` decision is not fixed
  silently. Ask the user: was the code change intended? If yes, record a new
  decision with the `lineage` skill and update the invariant. If no, it is a
  bug: leave the doc, and report the bug.
- Rewrite stale map lines and README sections. Keep maps within their line
  limits.
- Refresh stale learning docs with the `learning-docs` skill (it updates
  each `source_commit`).
- Run `sh .agents/kit/check.sh` again and show that it passes. Report every
  file changed.
