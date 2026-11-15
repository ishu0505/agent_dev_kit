# Todo

Next ID: 11

<!-- Ideas and follow-ups for a later session, one block per item. The todo
skill writes this file with sh .agents/kit/todo.sh (add, list, show, set,
done). Category is one of TODO_CATEGORIES in .agents/agent-kit.conf; Status
is open or doing. Refs are context for the work, not its limits. A done item
is deleted; git history keeps it. -->

## T-010: Add a headless overnight runner that fixes stale docs with claude, codex or agy

Category: task
Status: open
Added: 2026-11-15
From: T-009 (the runner half, put off when the scan shipped in 0.16.0)
Refs: `docs/plans/T-010-headless-docs-runner.agentk.md`, `doctor.sh`, `templates/kit/pre-edit.sh`, `templates/skills/docs-sync/SKILL.md`, `templates/skills/learning-docs/SKILL.md`, `templates/skills/interactive-docs/SKILL.md`, `templates/config/claude-settings.json`

One command (`sync-docs.sh --agent claude|codex|agy [folder]`) that skips repos `doctor.sh --stale` finds clean, then runs the agent headless in each stale repo with a `--force` mode of docs-sync, learning-docs and interactive-docs: read anywhere, write only docs, never code or commits, no permission prompts. Plan: `docs/plans/T-010-headless-docs-runner.agentk.md`.
