# <repo name>

<One line: what this repo does and for whom.>

Priorities, in this order when they conflict: **<first>**, **<second>**,
**<third>**.

## Where things are

| Path | What | Read first |
|---|---|---|
| `<folder>/` | <one line> | `<folder>/AGENTS.md` |
| `DECISIONS.md` | Lineage: every decision, its reason and its evidence | |

**Before working in a folder, read every `AGENTS.md` on the path from the root
to it.** Some agents load only the root map.

## Code style

- <the conventions the repo follows; match the file you are editing first>

## Invariants

- <rules a change must never break, each with the one place it lives>

## Check

```bash
<the repo's check command>
```

## Lineage

`DECISIONS.md` holds the reason for every choice. Run the `lineage` skill
(`.agents/skills/lineage/SKILL.md`) when a decision is made, an experiment
finishes, or a unit is added, moved or retired. New unit: the `scaffold`
skill.

## Keeping the docs true

- **The last step of every change is a docs step.** If code changed a default,
  an env var, a path, an interface or a behaviour, update the nearest README
  and `AGENTS.md` in the same change.
- **Every written plan ends with that docs step.**
- **`AGENTS.md` files are maps**: short, pointers not detail.
- If `learning_docs/` exists and the change touched a unit it explains,
  refresh it with the `learning-docs` skill.
- Checked by `.agents/kit/check.sh` on every commit (`.githooks/pre-commit`)
  and after every editing turn (Stop hook). `docs-sync check` reads deeper.
- **Skills live in `.agents/skills/`**; `.claude/skills` links to it.
