#!/bin/sh
# Which agents use the kit in this repo: a local log of session starts, the
# line the agent says first, and a report of each agent's wiring.
#
# Usage: sh .agents/kit/sessions.sh record <agent>   (the SessionStart hook)
#        sh .agents/kit/sessions.sh banner <agent>   (the line to say first)
#        sh .agents/kit/sessions.sh report           (agent, wiring, last session)
#
# The log is <git common dir>/agent-kit/sessions.log, one line per session
# start: <time> TAB <agent> TAB <kit version> TAB <branch> TAB <level>, where
# level is "workspace" when the workspace hook started it (AGENT_KIT_LEVEL),
# else "repo". It stays on this
# computer and keeps the last 200 lines. Agents: claude, codex, antigravity,
# cursor, other. Cursor has no kit hooks: only the use-adkit skill logs it;
# otherwise its sign is the first-reply line its rule or the root map asks for. The banner names the level: repo,
# repo + workspace (Claude, which also loads the workspace CLAUDE.md), or
# repo with the workspace map read on demand (the other agents).
# SESSION_BANNER="off" in .agents/agent-kit.conf stops the banner line.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0
SESSION_BANNER=on
MAPS=own
DOC_SUFFIX=".agentk.md"
[ -f .agents/kit/lib.sh ] && . ./.agents/kit/lib.sh && load_conf
LOG="$(git rev-parse --git-common-dir)/agent-kit/sessions.log"
VERSION=$(tr -d '\r\n' < .agents/kit/VERSION 2>/dev/null)
TAB=$(printf '\t')

record() {  # record <agent>: one log line, the log cut to its last 200 lines
  mkdir -p "$(dirname "$LOG")" || return 0
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "${1:-other}" "${VERSION:-unknown}" "$branch" "${AGENT_KIT_LEVEL:-repo}" >> "$LOG"
  if [ "$(wc -l < "$LOG")" -gt 200 ]; then
    tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
}
workspace_map() {  # the workspace map when this repo sits in a multi-repo workspace
  for up in .. ../..; do
    if [ -f "$up/.agent-workspace/workspace.conf" ] && [ -f "$up/WORKSPACE.agentk.md" ]; then
      echo "$up/WORKSPACE.agentk.md"; return
    fi
  done
}
banner() {  # banner <agent>: the instruction with the line to say first
  [ "$SESSION_BANNER" = off ] && return 0
  if [ "$MAPS" = beside ]; then
    maps="AGENTS${DOC_SUFFIX:-.agentk.md} beside the team's AGENTS.md"
  elif [ "${1:-}" = claude ]; then
    maps="AGENTS.md (via CLAUDE.md)"
  else
    maps="AGENTS.md"
  fi
  level="repo: $(basename "$ROOT") · level: repo"
  ws=$(workspace_map)
  if [ -n "$ws" ] && [ "${1:-}" = claude ]; then  # Claude loads the parent CLAUDE.md too
    level="repo: $(basename "$ROOT") · level: repo + workspace"; maps="$maps, $ws"
  elif [ -n "$ws" ]; then
    level="repo: $(basename "$ROOT") · level: repo (workspace map $ws read when a change crosses repos)"
  fi
  echo "agent-kit: start your first reply in this session with this one line, then never again: \"agent-kit ${VERSION:-unknown} · $level · map: $maps\". Later, the first time you read the map of another folder, say one line: \"agent-kit: now also using <its path>\"."
}
hooked() {  # hooked <file> <text>: wired when the file holds the text
  [ -f "$1" ] && grep -q "$2" "$1"
}
last_of() {  # last_of <agent>: its last session start, or never
  last=$(awk -F "$TAB" -v agent="$1" '$2 == agent { when = $1 " (kit " $3 ", " ($5 == "" ? "repo" : $5) " level)" } END { print when }' "$LOG" 2>/dev/null)
  echo "${last:-never}"
}
report() {  # one line per agent: agent TAB wiring TAB last session start
  wiring=no
  { hooked .claude/settings.json session-start.sh || hooked .claude/settings.local.json session-start.sh; } && wiring=hooks
  printf 'claude\t%s\t%s\n' "$wiring" "$(last_of claude)"
  wiring=no; hooked .codex/hooks.json session-start.sh && wiring=hooks
  printf 'codex\t%s\t%s\n' "$wiring" "$(last_of codex)"
  wiring=no; hooked .agents/hooks.json agy-hook.sh && wiring=hooks
  printf 'antigravity\t%s\t%s\n' "$wiring" "$(last_of antigravity)"
  wiring="map only"; [ -f .cursor/rules/agent-kit.mdc ] && wiring="local rule"
  last=$(last_of cursor)
  [ "$last" = never ] && last='not logged (no kit hooks): its first reply must start with "agent-kit"; /use-adkit logs it'
  printf 'cursor\t%s\t%s\n' "$wiring" "$last"
  other=$(last_of other)
  [ "$other" = never ] || printf 'other\t-\t%s\n' "$other"
}

case "${1:-}" in
  record) record "${2:-other}" ;;
  banner) banner "${2:-other}" ;;
  report) report ;;
  *) echo "usage: sessions.sh record <agent> | banner <agent> | report"; exit 2 ;;
esac
exit 0
