---
name: todo
description: Keep the repo's todo list (TODO.agentk.md at the root) - ideas and follow-ups for a later session, each with a category (task, bug, chore, experiment), a status and refs to files or folders that give context. Use when the user says todo, "add this to the todo", "what is in the todo", "what should I do next", "start T-007" or "T-007 is done"; when an experiment result suggests something to try next; and when an idea comes up that this session will not do. Arguments - add, list [category|open|doing], start <id>, done <id>.
---

# Todo

The todo list holds work for later: an idea, a bug seen in passing, a chore,
or the next experiment an earlier result suggests. It lives in
`TODO.agentk.md` at the repo root (`TODO<DOC_SUFFIX>`). It is shared or kept
local by `SHARE` in `.agents/agent-kit.conf`, like every kit doc; in a team
repo (`MAPS="beside"`) it never leaves this computer. Never commit it unless
the user asks.

`sh .agents/kit/todo.sh` owns the IDs, the Status line and deletion. You
write `From:`, `Refs:` and the notes with your edit tool. Never renumber an
item, and never reuse an ID.

## Add

1. Choose the category from `TODO_CATEGORIES` (default `task bug chore
   experiment`): a fault in existing behaviour is `bug`; upkeep with no new
   behaviour (upgrades, renames, clean-up) is `chore`; something to measure
   or try is `experiment`; the rest is `task`. Ask only when two fit.
2. Write the title as the work to do, in a few words: "Try batch size 32 for
   the reranker", not "batch size".
3. Run `sh .agents/kit/todo.sh add <category> "<title>"`. It prints the ID.
4. Fill the item's lines:
   - `From:` where the idea came from: an experiment (`E-012`), a decision
     (`D-004`), a pull request, a review, or "user idea".
   - `Refs:` paths in backticks that exist in the repo: files of any kind,
     Markdown docs, or folders (end a folder with `/`). Take them from the
     conversation; never invent one. They give context; they do not limit
     the work.
   - Notes under the fields: what is known so far, in one to three lines.
5. Tell the user in one line: ID, category, title.

When the user lists several ideas at once, add each as its own item.

## List

Run `sh .agents/kit/todo.sh list` (or with a category, `open` or `doing`).
Show a short table grouped by category: ID, status, title. For "what should
I do next", add one line on which item you would pick and why. Do not read
the refs to list them.

## Start

1. Run `sh .agents/kit/todo.sh show <id>` and read it.
2. Read its refs as background before you plan. Say once: "The refs are
   context, not the limit of the work." Look beyond them when the work
   needs it.
3. Run `sh .agents/kit/todo.sh set <id> doing`.
4. If the work spans sessions or parts, or needs a plan the user approves,
   open a task file (`sh .agents/kit/task.sh new <name>`) and write
   `Todo: <id>` as the first line of its Goal, so wrap-up can close both.

## Done

1. If the result is a decision or an experiment outcome, offer the
   `lineage` skill first, so it lasts after the item is gone. Do not run it
   without a yes.
2. If the work left new ideas, offer to add them as items, with
   `From: <id>`.
3. Run `sh .agents/kit/todo.sh done <id>`. It deletes the item; git history
   keeps it.

To drop an idea that will not be done, use the same command after the
user's yes.

## Errors

Every error of `todo.sh` prints its fix. `sh .agents/kit/check.sh` fails on
an unknown category or status and on a repeated ID, and warns when a ref
path no longer exists: update or remove that ref.
