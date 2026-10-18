#!/bin/sh
# Link the global `agent-kit` skill into every agent's user skill folder, so
# "agent-kit setup" works in any repo. Links, not copies: `git pull` in the
# kit updates every agent at once. Safe to run again.
#
#   ~/.claude/skills   Claude Code (CLI, desktop app, IDE extensions)
#   ~/.agents/skills   Codex, Cursor, Muse, Gemini CLI and other agents
#                      that read the shared Agent Skills folder
#   ~/.gemini/antigravity/skills   Antigravity
#   extra folders      AGENT_KIT_SKILL_DIRS="dir1 dir2" sh install-global.sh
#
# Remove: sh install-global.sh --remove

set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
SKILL="$KIT/global-skills/agent-kit"
DIRS="$HOME/.claude/skills $HOME/.agents/skills $HOME/.gemini/antigravity/skills ${AGENT_KIT_SKILL_DIRS:-}"

for dir in $DIRS; do
  link="$dir/agent-kit"
  if [ "${1:-}" = "--remove" ]; then
    [ -L "$link" ] && rm "$link" && echo "removed $link"
    continue
  fi
  mkdir -p "$dir"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "skipped $link: a real folder is there; move it away first"
    continue
  fi
  ln -sfn "$SKILL" "$link"
  echo "linked $link -> $SKILL"
done
