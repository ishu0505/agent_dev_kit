# agent_dev_kit

A kit that installs agent context into any repo: `AGENTS.md` maps, the
decision lineage, seven repo skills, docs checks, a catch-up queue for code
written by hand, and learning docs. Every Markdown file it writes into a
repo ends in `.agentk.md`; it never edits the repo's own docs. Humans start
at `README.md`.

## Map

| Path | What |
|---|---|
| `BOOTSTRAP.md` | The setup prompt an agent follows inside a target repo |
| `install.sh` | Copies kit files into a target repo; also the upgrade |
| `install-global.sh` | Links the `agent-kit` skill into each agent's skill folder |
| `global-skills/agent-kit/` | The one global skill: setup, upgrade, check |
| `templates/kit/` | `check.sh`, the Stop and SessionStart hooks, `queue.sh` (catch-up queue), `stale.sh`, `map-rows.sh`, `inventory.sh` (house cleaning), `writing-style.agentk.md`; copied to `.agents/kit/` |
| `templates/skills/` | `lineage`, `scaffold`, `docs-sync`, `learning-docs`, `wrap-up`, `catch-up`, `explain-diff` |
| `templates/config/` | `agent-kit.conf`, Claude and Codex hook configs |
| `templates/docs/` | Map, decision index and file, ledger, plan, learning-doc and command-card (`KIT.md`) templates |
| `templates/githooks/` | The pre-commit and post-commit hooks |
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
- **Kit-owned files** (`templates/kit/`, `templates/skills/`,
  `templates/githooks/`) are overwritten on upgrade; never put repo content
  in them. Repo-owned templates are created once and never overwritten.
- **Scripts are POSIX sh** with `git`, `grep`, `awk`, `sed`, `cksum` only,
  and must run on macOS, Linux and Windows Git Bash: no `sed -i`, no
  `readlink -f`, no `cmp`/`diff`, no GNU-only flags; tolerate CRLF input.
  The Stop hook is the one Python file (standard library, 3.9+) and must
  never block when it fails.
- **Every check failure prints its fix.**

## Before calling a change done

```bash
sh tests/run.sh
python3 guide/build.py
```

A change to a template bumps `VERSION` and adds a `CHANGELOG.md` entry that
says what an upgrading repo must do. Then update `README.md` if usage changed.
