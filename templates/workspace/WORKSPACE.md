# Workspace: <name>

This folder holds several git repos side by side. Each repo keeps its own
rules, its own commits and its own pull requests. This file says what each
repo is and how the repos connect.

<!-- agent-kit:repos (written by workspace.sh scan; edit only the Role column) -->
| Repo | Role | Kit | Read first |
|---|---|---|---|
<!-- /agent-kit:repos -->

## Contracts between repos

<What one repo gives that another repo uses: an API schema, shared types,
events, environment variables. One line each: the provider file, the
consumer folder, and what must stay the same. Put each one in LINKS in
`.agent-workspace/workspace.conf` too, so the hook reminds the agent.>

## Rules

- For a change in one repo, start the agent inside that repo. For a change
  that spans repos, start it in this folder.
- Inside a repo, that repo's own `AGENTS.md` and `CLAUDE.md` come first.
  This file only adds what no single repo can say.
- A change to a contract updates the provider and every consumer in the
  same task. Run the checks of each repo you changed
  (`sh <repo>/.agents/kit/check.sh` where the kit is installed).
- A repo with kit "declined" or "none": read its own `README.md` and
  `AGENTS.md`, and its light map in `.agent-workspace/maps/`. Never write
  kit files inside it.
- Commits, branches and pull requests stay per repo. Never commit in one
  repo for another.
