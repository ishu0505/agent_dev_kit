# agent_dev_kit

A kit that installs agent context into any repo: `AGENTS.md` maps, the
decision lineage, nine repo skills, docs checks, a catch-up queue for code
written by hand, a notice for teammates' pulled commits, learning docs, and
multi-repo workspaces. Every Markdown file it writes into a repo ends in
`.agentk.md`; it never edits the repo's own docs. Humans start at
`README.md`.

## Map

| Path | What |
|---|---|
| `BOOTSTRAP.md` | The setup prompt an agent follows inside a target repo |
| `WORKSPACE.md` | The setup prompt for a folder that holds several repos |
| `install.sh` | Copies kit files into a target repo; also the upgrade |
| `install-global.sh` | Links the `agent-kit` skill into each agent's skill folder |
| `global-skills/agent-kit/` | The one global skill: setup, upgrade, check, workspace |
| `templates/kit/` | `check.sh`, the Stop and SessionStart hooks, `queue.sh` (catch-up queue), `pulled.sh` (other people's commits since the docs were checked), `lib.sh` (config reader, shared helpers), `stale.sh`, `map-rows.sh`, `inventory.sh` (house cleaning), `agent-files.sh` (who owns each agent file), `wire.sh` (team repos: local wiring of the kit's maps), `writing-style.agentk.md`, `explain-standard.agentk.md` (80% STE, quiz ladder), `task.sh` + `task.agentk.md` (task files a target repo keeps in .agents/work/, never committed), `candidates.sh` (read-only candidates for a map's "Do not read" and "Lookalikes" rows); copied to `.agents/kit/` |
| `templates/workspace/` | `workspace.sh` (init, add, scan, where, status, decline), `ws-hook.sh`, the workspace map and config; copied to `<workspace>/.agent-workspace/` |
| `templates/skills/` | `lineage`, `scaffold`, `docs-sync`, `learning-docs`, `wrap-up`, `catch-up`, `explain-diff`, `explain-d-ez`, `explain-d-in` |
| `templates/config/` | `agent-kit.conf`, Claude and Codex hook configs |
| `templates/docs/` | Map (`AGENTS.root.md`, `AGENTS.beside.md` for team repos, `AGENTS.unit.md`), decision index and file, ledger, plan, learning-doc and command-card (`KIT.md`) templates |
| `templates/githooks/` | The pre-commit, post-commit and post-merge hooks; post-checkout (team repos) |
| `templates/ci/` | The GitHub Actions workflow (`install.sh --ci`) |
| `guide/` | The HTML guide: `template.html` + `build.py` |
| `tests/run.sh` | End-to-end tests in throwaway repos |
| `.github/workflows/test.yml` | CI: the tests on macOS, Ubuntu, Fedora and Windows |

## Rules

- **Templates are copied into other repos.** Keep them generic: no names,
  paths or languages from one project. Repo-specific values belong in
  `agent-kit.conf`.
- **Kit docs end in `DOC_SUFFIX` (`.agentk.md`)** in a target repo; only
  `AGENTS.md`, pointer files and `SKILL.md` keep their exact names. Skills
  and scripts must never write to the repo's own Markdown files.
- **Team repos (`MAPS="beside"`)**: the kit never edits or untracks a team
  file (`AGENTS.md`, `CLAUDE.md`, `.gitignore`, `.claude/settings.json`,
  hooks), and nothing it makes may be committed. Every new path the kit
  writes there must be in the beside exclude list in `install.sh` and in
  `kit_local_paths` in `check.sh`.
- **Kit-owned files** (`templates/kit/`, `templates/skills/`,
  `templates/githooks/`) are overwritten on upgrade; never put repo content
  in them. Repo-owned templates are created once and never overwritten.
- **Scripts are POSIX sh** with `git`, `grep`, `awk`, `sed`, `cksum` only,
  and must run on macOS, Linux and Windows Git Bash: no `sed -i`, no
  `readlink -f`, no `cmp`/`diff`, no GNU-only flags; tolerate CRLF input.
  The Stop hook is the one Python file (standard library, 3.9+) and must
  never block when it fails.
- **Every check failure prints its fix.**
- **Map warning rows are confirmed facts.** "Do not read unless asked",
  "Lookalikes" and "Hidden links" rows are written only after the user says
  yes; scripts may propose them, never write them.

## Before calling a change done

```bash
sh tests/run.sh
python3 guide/build.py
```

A change to a template bumps `VERSION` and adds a `CHANGELOG.md` entry that
says what an upgrading repo must do. Then update `README.md` if usage changed.
