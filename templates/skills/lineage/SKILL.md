---
name: lineage
description: Record a decision or an experiment result in the repo's lineage (DECISIONS.md and the experiment ledger), and bring the AGENTS.md maps up to date. Use when the user decides something about architecture, a model, a library, a stage or a tool; when an experiment or benchmark finishes; or when a folder, service or unit is added, moved, renamed or retired.
---

# Lineage

The lineage is `DECISIONS.md` (decisions) and, when the repo has one, the
experiment ledger named by `LEDGER` in `.agents/agent-kit.conf`. Both are
append-mostly: history is kept, and a changed mind is a new entry that
supersedes the old one.

## 1. Name the change

State in one sentence what was decided or measured. Done when the sentence
names a single choice and what it replaces.

## 2. Grill

Ask the user, one question at a time, until each has an answer in their own
words:

- **Why** this choice, toward which of the repo's priorities (root
  `AGENTS.md`)?
- **What else** was considered, and why did it lose?
- **What evidence** supports it? A report path and its numbers, or "none yet".
- **What would reverse it?** A result, a cost, a scale.

Push back on an answer that restates the decision, cites no evidence, or
contradicts an earlier entry in `DECISIONS.md`; quote that entry. Accept
"I don't know yet" and record it as open. Done when all four are answered or
explicitly open.

## 3. Write the decision

Append to `DECISIONS.md` using the template at its top, with the next free
id and today's date. Record the user's reasoning as they gave it; mark any
inference of yours as yours. When the entry replaces an earlier one, set that
entry's status to `superseded by D-NNN` and change nothing else in it.

## 4. Update the experiment ledger

When an experiment was involved and `LEDGER` is set, add or update its row:
folder, question, scale (documents, questions, runs), outcome (a number, or
`pending: not run yet`), report path, decision id.

## 5. Update the maps

Check each `AGENTS.md` the change touches, from the root down to the unit:

- add, move or remove map rows so every listed path exists;
- add or reword an invariant the decision creates or ends;
- delete lines the change made stale.

Keep maps within `TOP_MAP_MAX` and `UNIT_MAP_MAX` lines (config). Detail
belongs in the README or report the map points to. A new unit gets its map
from the `scaffold` skill.

## 6. Check and report

Run `sh .agents/kit/check.sh`. Tell the user which entries and lines
changed, and list every open question left from step 2.
