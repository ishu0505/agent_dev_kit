# <repo name>

<One line: what this repo does and for whom.>

Priorities, in this order when they conflict: **<first>**, **<second>**,
**<third>**.

## Where things are

| Path | What | Read first |
|---|---|---|
| `<folder>/` | <one line> | `<folder>/AGENTS.md` |
| `DECISIONS.agentk.md` | Every decision, its reason and its evidence | |
| `KIT.agentk.md` | How to use the agent kit here | |

Before you work in a folder, read the `AGENTS.md` maps on the path to it.
Read nothing else until the task needs it.

## Code style

- <the conventions the repo follows; match the file you are editing first>

## Invariants

- <rules a change must never break, each with the one place it lives>

<!-- Optional, rows the user confirmed, at most five each; delete if empty. -->
## Do not read unless asked
- `<path>` — <generated / old copy / test data>
## Lookalikes
- `<right path>`, not `<wrong path>` — <how to tell them apart>
## Hidden links
- `<path>` → `<path>` — <a link search cannot find; never a normal import>

## Tasks

- Open a task file (`sh .agents/kit/task.sh new <name>`) when the work spans
  sessions or units, needs my OK on a plan, or is an investigation to keep.
  Tell me; I can say no. Small fixes, questions, doc fixes: no task file.
- After each step, update its Found, Decisions, Done and Next. Continue a
  task only from its file.

## Check

```bash
<the repo's check command>
```

## Docs

- A map points to detail; it does not hold it. Keep it short.
- Write only kit docs: `AGENTS.md`, pointer files, and files ending in
  `.agentk.md`. Every other Markdown file belongs to the people here: read
  it, report drift in it, never edit it.
- At the end of every task, and before a pull request, run the `wrap-up`
  skill. Other skills (`lineage`, `scaffold`, `catch-up`, `explain-diff`,
  `explain-d-ez`, `explain-d-in`) are in `.agents/skills/`. Run
  `interactive-docs` and `arch-emulator` only when the user names them.
