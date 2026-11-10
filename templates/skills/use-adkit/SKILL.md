---
name: use-adkit
description: Load this repo's agent-kit context into the current chat by hand - the kit version, the root map (and the team's AGENTS.md first in a team repo), the maps on the path to the files of the task, what waits (catch-up, pulled commits, todos) and the coding standard - then say the session line and go on with the prompt. Use when the user types use-adkit (/use-adkit, $use-adkit) before or inside a prompt, says "use the agent kit", or when a reply had no "agent-kit" line (Cursor, or an agent whose hooks did not run). Arguments - the rest of the prompt, or files and folders to load the maps for.
---

# Use the agent kit in this chat

The kit's hooks and map files load its context by themselves in Claude
Code, Codex and Antigravity. This skill does the same by hand, for a chat
where that did not happen. It reads; it changes nothing in the repo.

## 1. Load

1. Find the repo root (`git rev-parse --show-toplevel`). If
   `.agents/kit/VERSION` is missing, say "agent-kit is not installed in
   this repo" and stop; `agent-kit setup` installs it.
2. Run `AGENT_KIT_AGENT=<you> sh .agents/kit/session-start.sh --load
   </dev/null`, where `<you>` is the app you run in: `claude`, `codex`,
   `antigravity`, `cursor` or `other`. It logs the session, refreshes the
   local wiring, and prints the session line to say, what waits, and the
   coding standard. Follow its lines as a session start would.
3. Read the root map: `AGENTS.md`. In a team repo (`MAPS="beside"` in
   `.agents/agent-kit.conf`), read the team's `AGENTS.md` (and `CLAUDE.md`)
   first, then `AGENTS.agentk.md`. The team's rules come first.
4. If the repo sits in a multi-repo workspace (a parent folder with
   `.agent-workspace/`), note `../WORKSPACE.agentk.md`; read it when the
   task touches another repo.
5. For each file or folder the prompt names, read the maps on the path to
   it, root first.

## 2. Say it

Start the reply with the session line from step 2, with every map you read
in step 3 to 5 after `map:`. Then go on with the rest of the prompt; with
no prompt, stop after the line and one line on what waits.

Follow what the session start printed: with "every reply" (the default),
start each later reply with the line too, add the maps you read for that
prompt, and end each reply with the "agent-kit used:" line. With "first
reply" only, say "agent-kit: now also using <its path>" the first time you
read another folder's map.
