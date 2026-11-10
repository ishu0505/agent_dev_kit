#!/bin/sh
# The agent hooks of a multi-repo workspace, for an agent started in the
# workspace folder (an agent started inside one repo uses that repo's hooks).
#
# Usage: sh .agent-workspace/kit/ws-hook.sh session-start   (the hook event JSON on stdin)
#        sh .agent-workspace/kit/ws-hook.sh turn   (UserPromptSubmit: the session line ask)
#        sh .agent-workspace/kit/ws-hook.sh stop
#
# session-start: each repo with the kit runs its own session start (the
#   lines get the repo name), the coding standard is printed once, and repos
#   that wait for an answer about the kit are named once.
# stop: the docs step for every repo with the kit at once, one message, plus
#   a reminder when a provider file named in LINKS changed (see
#   .agent-workspace/workspace.conf). Never blocks when something fails.
ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 0
cd "$ROOT" || exit 0
input=$(cat)
repos=$(sh .agent-workspace/kit/workspace.sh repos 2>/dev/null)
kit_repos=$(printf '%s\n' "$repos" | awk -F'\t' '$2 == "kit" { print $1 }')

python_cmd() {  # the first Python 3.9+ on this computer
  for python in python3 python py; do
    if command -v "$python" >/dev/null 2>&1 &&
       "$python" -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
      echo "$python"; return 0
    fi
  done
  return 1
}
reminder() {  # reminder [--baseline]: the Python docs step for the whole workspace
  python=$(python_cmd) || return 0
  set -- "$@" --workspace "$ROOT" --repos
  while IFS= read -r repo; do [ -n "$repo" ] && set -- "$@" "$repo"; done <<EOF
$kit_repos
EOF
  printf '%s' "$input" | "$python" .agent-workspace/kit/docs_reminder.py "$@" 2>/dev/null
}

banner_setting() {  # every (also "on", the default), first or off
  setting=$(sed -n 's/^SESSION_BANNER="\{0,1\}\([a-z]*\).*/\1/p' .agent-workspace/workspace.conf 2>/dev/null | tail -1)
  case "$setting" in off|first) echo "$setting" ;; *) echo every ;; esac
}
workspace_line() {  # "agent-kit <version> · level: workspace · ..."
  version=$(tr -d '\r\n' < .agent-workspace/kit/VERSION 2>/dev/null)
  versions=$(printf '%s\n' "$kit_repos" | while IFS= read -r repo; do
    [ -n "$repo" ] && printf '%s %s, ' "$repo" "$(tr -d '\r\n' < "$repo/.agents/kit/VERSION" 2>/dev/null)"
  done | sed 's/, $//')
  echo "agent-kit ${version:-unknown} · level: workspace · map: WORKSPACE.agentk.md · repos with the kit: ${versions:-none}"
}
banner() {  # banner [turn]: the session line ask; "turn" for the per-prompt hook
  setting=$(banner_setting)
  [ "$setting" = off ] && return 0
  if [ "$setting" = first ]; then
    [ "${1:-}" = turn ] && return 0
    echo "agent-kit workspace: start your first reply in this session with this one line, then never again: \"$(workspace_line)\". Later, the first time you read a repo's map, say one line: \"agent-kit: now also using <its path> (repo level)\"."
    return 0
  fi
  echo "agent-kit workspace: start every reply with this one line: \"$(workspace_line)\", with the path of each repo map you read for this prompt added after \"map:\". End every reply with one line: \"agent-kit used: maps <the maps you read for this prompt, or none> · skills <the skills you ran, or none> · tools <each tool you called with its count, such as Read ×3, Bash ×2, or none>\"."
}

case "${1:-}" in
  session-start)
    banner
    printf '%s\n' "$kit_repos" | while IFS= read -r repo; do
      [ -n "$repo" ] && [ -f "$repo/.agents/kit/session-start.sh" ] || continue
      (cd "$repo" && printf '%s' "$input" | AGENT_KIT_SKIP_STANDARD=1 AGENT_KIT_SKIP_BANNER=1 AGENT_KIT_LEVEL=workspace sh .agents/kit/session-start.sh 2>/dev/null) |
        sed "s|^agent-kit: |agent-kit [$repo]: |"
    done
    # The coding standard once, from the first repo that has it on.
    printf '%s\n' "$kit_repos" | while IFS= read -r repo; do
      standard="$repo/.agents/kit/coding-standard.agentk.md"
      [ -n "$repo" ] && [ -f "$standard" ] || continue
      setting=$(cd "$repo" && CODING_STANDARD=on && . ./.agents/kit/lib.sh 2>/dev/null && load_conf && echo "$CODING_STANDARD")
      [ "$setting" = off ] && continue
      echo "agent-kit workspace: the coding standard ($standard) follows. Apply it whenever you plan or write code in a repo that has the kit."
      tr -d '\r' < "$standard"
      break
    done
    reminder --baseline >/dev/null
    waiting=$(printf '%s\n' "$repos" | awk -F'\t' '$2 == "none" { printf "%s%s", sep, $1; sep = ", " }')
    [ -n "$waiting" ] &&
      echo "agent-kit workspace: no answer yet about the kit for: $waiting. Ask the user once (install / not now / never), with: sh .agent-workspace/kit/workspace.sh scan"
    linked=$(printf '%s\n' "$repos" | awk -F'\t' '$2 == "symlink" { printf "%s%s", sep, $1; sep = ", " }')
    [ -n "$linked" ] &&
      echo "agent-kit workspace: symlinked repos are not supported: $linked (run workspace.sh scan for the fix)"
    ;;
  turn) banner turn ;;
  stop) reminder ;;
  *) echo "usage: ws-hook.sh session-start|turn|stop"; exit 2 ;;
esac
exit 0
