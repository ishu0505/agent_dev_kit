#!/bin/sh
# Install or upgrade the agent kit in a git repository.
#
# Usage: /path/to/agent_dev_kit/install.sh [target repo, default: current repo]
#
# Safe to run again: that is how a repo upgrades. Kit-owned files are
# replaced; repo-owned files are created only when missing and never
# overwritten. Anything it cannot do safely is printed under "For the agent".

set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
T="$KIT/templates"
TARGET=${1:-.}
ROOT=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null) || {
  echo "agent-kit: $TARGET is not a git repository. Run: git init"; exit 1; }
cd "$ROOT"

NEW_VERSION=$(cat "$KIT/VERSION")
OLD_VERSION=$(cat .agents/kit/VERSION 2>/dev/null || echo "none")
NOTES=""
note() { NOTES="$NOTES
- $1"; }
say() { echo "  $1"; }

create_if_missing() {  # create_if_missing <template> <destination>
  if [ -e "$2" ]; then return 1; fi
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  say "created $2"
}

echo "agent-kit $NEW_VERSION -> $ROOT (installed before: $OLD_VERSION)"

# Kit-owned: always replaced.
mkdir -p .agents/kit .agents/skills .githooks
cp "$T"/kit/*.sh "$T/kit/docs_reminder.py" .agents/kit/
cp "$KIT/VERSION" .agents/kit/VERSION
chmod +x .agents/kit/*.sh
say "updated .agents/kit/ (check.sh, sync-skills.sh, stop hook, VERSION)"
for skill in "$T"/skills/*/; do
  name=$(basename "$skill")
  rm -rf ".agents/skills/$name"
  cp -R "$skill" ".agents/skills/$name"
  say "updated .agents/skills/$name"
done

# Pre-commit: ours is replaced; someone else's is left for the agent to merge.
if [ ! -f .githooks/pre-commit ] || grep -q 'agents/kit/check.sh' .githooks/pre-commit; then
  cp "$T/githooks/pre-commit" .githooks/pre-commit
  chmod +x .githooks/pre-commit
  say "updated .githooks/pre-commit"
else
  note ".githooks/pre-commit already exists: add the line  sh \"\$(git rev-parse --show-toplevel)/.agents/kit/check.sh\" --quiet || exit 1"
fi
hooks_path=$(git config core.hooksPath || true)
if [ -z "$hooks_path" ]; then
  git config core.hooksPath .githooks
  say "set git config core.hooksPath .githooks (this clone)"
elif [ "$hooks_path" != ".githooks" ]; then
  note "core.hooksPath is $hooks_path: call .agents/kit/check.sh --quiet from its pre-commit"
fi

# Repo-owned: created once, never overwritten.
create_if_missing "$T/config/agent-kit.conf" .agents/agent-kit.conf || true
create_if_missing "$T/config/codex-hooks.json" .codex/hooks.json || true
if ! create_if_missing "$T/config/claude-settings.json" .claude/settings.json; then
  grep -q 'agents/kit/stop-hook.sh' .claude/settings.json ||
    note ".claude/settings.json exists: merge the Stop hook from $T/config/claude-settings.json (and remove any older docs hook)"
fi
grep -q 'agents/kit/stop-hook.sh' .codex/hooks.json ||
  note ".codex/hooks.json exists: merge the Stop hook from $T/config/codex-hooks.json"
# .claude/skills: a link, or a copy where symlinks fail (Windows).
skills_mode=$(sed -n 's/^SKILLS_LINK="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' .agents/agent-kit.conf)
if [ -d .claude/skills ] && [ ! -L .claude/skills ] && [ "$skills_mode" != "copy" ]; then
  note ".claude/skills is a real folder: move its own skills into .agents/skills, then run: sh .agents/kit/sync-skills.sh"
elif [ ! -L .claude/skills ]; then
  sh .agents/kit/sync-skills.sh | sed 's/^/  /'
fi

# Line endings: scripts must stay LF on every OS.
if [ "$(git check-attr eol -- .agents/kit/check.sh | sed 's/.*: //')" != "lf" ]; then
  [ -s .gitattributes ] && printf '\n' >> .gitattributes
  cat "$T/config/gitattributes" >> .gitattributes
  say "added LF line-ending rules to .gitattributes"
fi

# Learning docs stay local.
LEARNING_DIR=$(sed -n 's/^LEARNING_DIR="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' .agents/agent-kit.conf)
if [ -n "$LEARNING_DIR" ] && ! git check-ignore -q "$LEARNING_DIR/probe.md"; then
  printf '\n# Local learning docs (agent-kit); never committed\n%s/\n' "$LEARNING_DIR" >> .gitignore
  say "added $LEARNING_DIR/ to .gitignore"
fi

# Executable bit in git, so macOS and Linux clones of a repo set up on
# Windows still run the hooks. This stages these few files.
git add --chmod=+x .githooks/pre-commit .agents/kit/*.sh 2>/dev/null &&
  say "staged scripts as executable (git add --chmod=+x)"

if [ -n "$NOTES" ]; then
  echo
  echo "For the agent:$NOTES"
fi
echo
echo "Checks now (failures are expected until the maps are written):"
sh .agents/kit/check.sh || true
