## Agent context

This repo uses [agent_dev_kit](<kit url>): `AGENTS.md` maps for coding
agents, `DECISIONS.md` for the reason behind each choice, skills in
`.agents/skills/`, and checks that keep the docs true.

| Situation | Do this |
|---|---|
| Fresh clone, once | `git config core.hooksPath .githooks` |
| Quick check (seconds, no AI) | `sh .agents/kit/check.sh` |
| End of a task, or before a PR | ask the agent: `wrap-up` |
| You wrote code by hand | `catch-up`: the agent explains it, proposes docs and docstrings, you approve |
| Explain a branch or PR, with a quiz | `explain-diff` (`explain-diff --post` adds it to the PR) |
| Are code and docs in sync? | `docs-sync check` |
| Make the docs match the code | `docs-sync fix` |
| Learn the system | `learning-docs` (writes `learning_docs/`; pushed only in share mode `all` or `learning`) |
| Tidy agent and doc files | `agent-kit cleanup` |
| Record a decision or result | `lineage` |
| Which docs may be stale? | `sh .agents/kit/stale.sh` (read only) |
| A commit that needs no docs | put `[no-docs]` in its message |
| Add a service, package or experiment | `scaffold` |
| Edited a skill (copy mode) | `sh .agents/kit/sync-skills.sh` |
| Newer kit version | in the kit folder `git pull`, then ask the agent: `agent-kit upgrade` |

On Windows, run the shell commands in Git Bash. How to call a skill: Claude Code and agy `/docs-sync check`; Codex `$docs-sync check`. Cursor,
Antigravity and other agents that load `.agents/skills`: name the skill.
Any agent: "Read `.agents/skills/docs-sync/SKILL.md` and run it in check
mode."
