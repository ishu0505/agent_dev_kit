# Changelog

Each entry says what changed and what a repo must do when it upgrades
(`agent-kit upgrade`). Versions follow `VERSION`.

## 0.1.0 — 2026-10-18

First release, extracted from docu_nom_nom_69's hand-made setup.

- `check.sh` (POSIX sh): map size, dead paths, unit README / map / pointer
  files, one skill copy, agent files tracked, portable hooks, pre-commit
  active, experiment ledger outcomes, learning docs never tracked.
- Stop hook for Claude Code and Codex: runs the checks after an editing turn
  (shell edits included) and asks for the docs step after a code edit.
- Skills: `lineage`, `scaffold`, `docs-sync` (check / fix), `learning-docs`
  (ASD-STE100, code references, quizzes with hidden answers).
- `install.sh` (also the upgrade), `install-global.sh` (the `agent-kit`
  skill for Claude Code, Codex, Cursor, Muse, Antigravity, Gemini CLI).

Upgrading from a hand-made setup: run `agent-kit upgrade`; it lists old
hooks and check scripts the kit replaces, and proposes removing them.
