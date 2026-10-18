## Agent context

This repo uses [agent_dev_kit](https://github.com/ishu0505/agent_dev_kit): `AGENTS.md` maps for coding
agents, `DECISIONS.md` for the reason behind each choice, skills in
`.agents/skills/`, and checks that keep the docs true.

| Situation | Do this |
|---|---|
| Fresh clone, once | `git config core.hooksPath .githooks` |
| Quick check (seconds, no AI) | `sh .agents/kit/check.sh` |
| Are code and docs in sync? | ask the agent: `docs-sync check` |
| Make the docs match the code | `docs-sync fix` |
| Learn the system | `learning-docs` (writes local `learning_docs/`, never committed) |
| Record a decision or result | `lineage` |
| Add a service, package or experiment | `scaffold` |
| Edited a skill (copy mode) | `sh .agents/kit/sync-skills.sh` |
| Newer kit version | in the kit folder `git pull`, then ask the agent: `agent-kit upgrade` |

On Windows, run the shell commands in Git Bash. How to call a skill: Claude Code and agy `/docs-sync check`; Codex `$docs-sync check`. Cursor,
Antigravity and other agents that load `.agents/skills`: name the skill.
Any agent: "Read `.agents/skills/docs-sync/SKILL.md` and run it in check
mode."
