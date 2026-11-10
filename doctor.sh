#!/bin/sh
# Which repos in a folder use the kit, and which agents use it there.
# Read only. Run it from the kit, at a folder that holds repos (a Cursor or
# VS Code workspace, a multi-repo workspace) or inside one repo.
#
# Usage: sh <agent_dev_kit>/doctor.sh [folder]   (default: the current folder)
#
# For each git repo (the folder itself and its subfolders, two levels down):
# the kit version (or "no kit"), the level (repo, or part of a workspace), and
# per agent its wiring and its last session start from that repo's
# sessions.log. Cursor has no kit hooks: its sign is the first-reply line.
KIT=$(cd "$(dirname "$0")" && pwd)
LATEST=$(tr -d '\r\n' < "$KIT/VERSION")
FOLDER=${1:-.}
cd "$FOLDER" || { echo "doctor: no folder $FOLDER"; exit 1; }
FOLDER=$(pwd)

if [ -f .agent-workspace/workspace.conf ]; then
  echo "Workspace: $FOLDER (kit $(tr -d '\r\n' < .agent-workspace/kit/VERSION 2>/dev/null), map WORKSPACE.agentk.md)"
  echo
fi

repos=$( { [ -e .git ] && echo .
  find . -mindepth 2 -maxdepth 3 -name .git -prune -print 2>/dev/null | sed 's|/\.git$||'
} | LC_ALL=C sort -u)
[ -n "$repos" ] || { echo "doctor: no git repos in $FOLDER or two levels below it."; exit 0; }

for repo in $repos; do
  name=${repo#./}; [ "$repo" = . ] && name="$(basename "$FOLDER") (this folder)"
  if [ ! -f "$repo/.agents/kit/VERSION" ]; then
    echo "$name: no kit"
    continue
  fi
  version=$(tr -d '\r\n' < "$repo/.agents/kit/VERSION")
  note=""; [ "$version" = "$LATEST" ] || note=" (kit $LATEST is out: agent-kit upgrade)"
  level=repo
  for up in .. ../..; do
    [ -f "$repo/$up/.agent-workspace/workspace.conf" ] && { level="repo, in a workspace"; break; }
  done
  echo "$name: kit $version$note; level: $level"
  if [ -f "$repo/.agents/kit/sessions.sh" ]; then
    (cd "$repo" && sh .agents/kit/sessions.sh report) | awk -F '\t' '{ printf "  %-12s %-24s last session: %s\n", $1, $2, $3 }'
  else
    echo "  (this kit has no session log: upgrade to 0.14.0 or later to see each agent)"
  fi
done
echo
echo "A repo where an agent says never or no: that agent does not get the kit there."
echo "Cursor: open a chat in each repo; its first reply must start with \"agent-kit\". If not, type /use-adkit."
