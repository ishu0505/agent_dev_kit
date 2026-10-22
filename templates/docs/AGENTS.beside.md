# <repo name>: my map

<One line: what this repo does.>

**Team rules come first.** The team's `AGENTS.md` and `CLAUDE.md` are the
rules here; agents load them with this file. This file only adds my map and
my own rules; it never repeats theirs. When the two disagree, follow the
team's file and tell me. This file is local: it is never committed.

## Where things are

| Path | What | Read first |
|---|---|---|
| `<folder>/` | <one line> | `<folder>/AGENTS.agentk.md` |

Before you work in a folder, read the `AGENTS.agentk.md` maps on the path to
it, after the team's `AGENTS.md` there.

## My rules

- <rules the team's files do not cover; never one that contradicts them>

## Check

```bash
<the repo's check command, from the team's docs>
```

## Docs

- Write only kit docs: `AGENTS.agentk.md`, and files ending in `.agentk.md`.
  The team's `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `README.md` and every
  other Markdown file are theirs: read them, report drift, never edit them.
- At the end of every task, and before a pull request, run the `wrap-up`
  skill. Never commit a kit file: nothing of mine goes to the team's repo.
