# <repo name>

<One line: what this repo does and for whom.>

Priorities, in this order when they conflict: **<first>**, **<second>**,
**<third>**.

## Where things are

| Path | What | Read first |
|---|---|---|
| `<folder>/` | <one line> | `<folder>/AGENTS.md` |
| `DECISIONS.md` | Every decision, its reason and its evidence | |

Before you work in a folder, read the `AGENTS.md` maps on the path to it.
Read nothing else until the task needs it.

## Code style

- <the conventions the repo follows; match the file you are editing first>

## Invariants

- <rules a change must never break, each with the one place it lives>

## Check

```bash
<the repo's check command>
```

## Docs

- A map points to detail; it does not hold it. Keep it short.
- At the end of every task, and before a pull request, run the `wrap-up`
  skill. Other skills (`lineage`, `scaffold`, `catch-up`, `explain-diff`)
  are in `.agents/skills/`.
