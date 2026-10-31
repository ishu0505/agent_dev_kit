#!/bin/sh
# The agent hooks of a multi-repo workspace, for an agent started in the
# workspace folder (an agent started inside one repo uses that repo's hooks).
#
# Usage: sh .agent-workspace/kit/ws-hook.sh session-start   (the hook event JSON on stdin)
#        sh .agent-workspace/kit/ws-hook.sh stop
#
# session-start: each repo with the kit runs its own session start (the
#   lines get the repo name), and repos that wait for an answer about the
#   kit are named once.
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

case "${1:-}" in
  session-start)
    printf '%s\n' "$kit_repos" | while IFS= read -r repo; do
      [ -n "$repo" ] && [ -f "$repo/.agents/kit/session-start.sh" ] || continue
      (cd "$repo" && printf '%s' "$input" | sh .agents/kit/session-start.sh 2>/dev/null) |
        sed "s|^agent-kit: |agent-kit [$repo]: |"
    done
    reminder --baseline >/dev/null
    waiting=$(printf '%s\n' "$repos" | awk -F'\t' '$2 == "none" { printf "%s%s", sep, $1; sep = ", " }')
    [ -n "$waiting" ] &&
      echo "agent-kit workspace: no answer yet about the kit for: $waiting. Ask the user once (install / not now / never), with: sh .agent-workspace/kit/workspace.sh scan"
    linked=$(printf '%s\n' "$repos" | awk -F'\t' '$2 == "symlink" { printf "%s%s", sep, $1; sep = ", " }')
    [ -n "$linked" ] &&
      echo "agent-kit workspace: symlinked repos are not supported: $linked (run workspace.sh scan for the fix)"
    ;;
  stop) reminder ;;
  *) echo "usage: ws-hook.sh session-start|stop"; exit 2 ;;
esac
exit 0
