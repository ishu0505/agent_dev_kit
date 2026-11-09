#!/bin/sh
# Antigravity hook adapter (agy CLI, Antigravity IDE and app), run from
# .agents/hooks.json. Antigravity sends camelCase JSON (conversationId,
# workspacePaths) and wants its own output shapes, so this turns its events
# into the kit's own hooks:
#   session-start  runs session-start.sh and returns its lines as a system
#                  message: {"injectSteps": [{"systemMessage": {...}}]}
#   stop           runs stop-hook.sh --agy, which prints
#                  {"decision": "continue", "reason": ...} when the docs
#                  step or the checks need the agent to go on
# Never fails: a broken hook must not stop the agent.
# Installed by agent_dev_kit; do not edit here.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0
input=$(cat)

json_string() {  # stdin as one JSON string body: \ " tab and newlines escaped, CR dropped
  awk 'BEGIN { ORS = "" }
    { gsub(/\r/, ""); gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t")
      if (NR > 1) print "\\n"; print }'
}

case "${1:-}" in
  session-start)
    lines=$(printf '%s' "$input" | sh .agents/kit/session-start.sh --agy 2>/dev/null)
    # Antigravity loads AGENTS.md and GEMINI.md by name only, so in a team repo
    # it would never see the kit's map without this line.
    MAPS=own; DOC_SUFFIX=".agentk.md"
    . ./.agents/kit/lib.sh 2>/dev/null && load_conf
    map="AGENTS${DOC_SUFFIX:-.agentk.md}"
    if [ "$MAPS" = beside ] && [ -f "$map" ]; then
      lines="agent-kit: your map here is $map, beside the team's AGENTS.md. Read it now, and the $map beside each folder's AGENTS.md before you work there; the team's rules come first.
$lines"
    fi
    [ -n "$lines" ] || exit 0
    printf '{"injectSteps": [{"systemMessage": {"systemMessage": "%s"}}]}\n' "$(printf '%s\n' "$lines" | json_string)"
    ;;
  stop)
    printf '%s' "$input" | sh .agents/kit/stop-hook.sh --agy 2>/dev/null
    ;;
esac
exit 0
