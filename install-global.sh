#!/bin/sh
# Put the global `agent-kit` skill into every agent's user skill folder, so
# "agent-kit setup" works in any repo. Safe to run again.
#
#   ~/.claude/skills               Claude Code (CLI, desktop app, IDEs)
#   ~/.agents/skills               Codex, Cursor, Muse, Gemini CLI and other
#                                  agents that read the shared skills folder
#   ~/.gemini/antigravity/skills   Antigravity
#   extra folders                  AGENT_KIT_SKILL_DIRS="dir1 dir2" sh install-global.sh
#
# macOS and Linux get symlinks: `git pull` in the kit updates every agent.
# Where symlinks fail (Windows Git Bash without Developer Mode) it copies,
# writes the kit's location into the copy, and you run this again after
# each `git pull`.
#
# Remove: sh install-global.sh --remove

set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
SKILL="$KIT/global-skills/agent-kit"
DIRS="$HOME/.claude/skills $HOME/.agents/skills $HOME/.gemini/antigravity/skills ${AGENT_KIT_SKILL_DIRS:-}"
COPIED=0

for dir in $DIRS; do
  link="$dir/agent-kit"
  if [ "${1:-}" = "--remove" ]; then
    if [ -L "$link" ] || [ -f "$link/kit-path" ]; then rm -rf "$link" && echo "removed $link"; fi
    continue
  fi
  mkdir -p "$dir"
  if [ -e "$link" ] && [ ! -L "$link" ] && [ ! -f "$link/kit-path" ]; then
    echo "skipped $link: a folder not made by agent-kit is there; move it away first"
    continue
  fi
  rm -rf "$link"
  ln -s "$SKILL" "$link" 2>/dev/null || true
  if [ -L "$link" ]; then
    echo "linked $link -> $SKILL"
  else
    rm -rf "$link"
    cp -R "$SKILL" "$link"
    printf '%s\n' "$KIT" > "$link/kit-path"
    echo "copied $link (symlinks are off here)"
    COPIED=1
  fi
done

[ "$COPIED" = 0 ] || echo "Copies do not follow 'git pull': run this script again after updating the kit."
