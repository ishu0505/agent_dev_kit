#!/bin/sh
# Install or upgrade the agent kit in a git repository.
#
# Usage: /path/to/agent_dev_kit/install.sh [--share MODE] [target repo]
#
#   --share agent     agent files pushed, learning docs local (default)
#   --share all       agent files and learning docs pushed
#   --share learning  learning docs pushed, agent files local
#   --share none      nothing pushed; everything stays on this machine
#
# Without --share, an installed repo keeps its mode (SHARE in
# .agents/agent-kit.conf). Safe to run again: that is how a repo upgrades.
# Kit-owned files are replaced; repo-owned files are created only when
# missing and never overwritten. Anything it cannot do safely is printed
# under "For the agent".

set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
T="$KIT/templates"
SHARE_ARG=""
TARGET="."
while [ $# -gt 0 ]; do
  case "$1" in
    --share) SHARE_ARG=${2:-}; shift 2 ;;
    --share=*) SHARE_ARG=${1#--share=}; shift ;;
    *) TARGET=$1; shift ;;
  esac
done
case "$SHARE_ARG" in
  ""|agent|all|learning|none) ;;
  *) echo "agent-kit: --share must be agent, all, learning or none"; exit 1 ;;
esac
ROOT=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null) || {
  echo "agent-kit: $TARGET is not a git repository. Run: git init"; exit 1; }
cd "$ROOT"

NEW_VERSION=$(cat "$KIT/VERSION")
OLD_VERSION=$(cat .agents/kit/VERSION 2>/dev/null || echo "none")
NOTES=""
note() { NOTES="$NOTES
- $1"; }
say() { echo "  $1"; }
conf() {  # conf <KEY>: a value from .agents/agent-kit.conf
  sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}\$/\1/p" .agents/agent-kit.conf | tail -1
}
set_conf() {  # set_conf <KEY> <value>: replace or add a config line
  if grep -q "^$1=" .agents/agent-kit.conf; then
    sed "s|^$1=.*|$1=\"$2\"|" .agents/agent-kit.conf > .agents/agent-kit.conf.tmp &&
      mv .agents/agent-kit.conf.tmp .agents/agent-kit.conf
  else
    printf '\n%s="%s"\n' "$1" "$2" >> .agents/agent-kit.conf
  fi
}
create_if_missing() {  # create_if_missing <template> <destination>
  if [ -e "$2" ]; then return 1; fi
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  say "created $2"
}
write_block() {  # write_block <file> <lines>: replace the agent-kit block (empty: remove it)
  start="# >>> agent-kit (managed by install.sh; edit SHARE in .agents/agent-kit.conf)"
  end="# <<< agent-kit"
  if [ -f "$1" ]; then
    awk -v s="$start" -v e="$end" '$0 == s { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$1" > "$1.tmp"
    mv "$1.tmp" "$1"
  fi
  if [ -n "$2" ]; then
    mkdir -p "$(dirname "$1")"
    [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ] && printf '\n' >> "$1"
    printf '%s\n%s\n%s\n' "$start" "$2" "$end" >> "$1"
  fi
  if [ -f "$1" ] && [ ! -s "$1" ]; then rm "$1"; fi
}
remove_legacy_rules() {  # rules written by kit 0.1 / 0.2 before blocks existed
  if [ -f .gitignore ]; then
    awk '/^# Local learning docs \(agent-kit\); never committed$/ { drop = 1; next }
         drop { drop = 0; next } { print }' .gitignore > .gitignore.tmp && mv .gitignore.tmp .gitignore
  fi
  if [ -f .gitattributes ]; then
    awk '/^# agent-kit: scripts and config keep LF line endings on every OS$/ { drop = 1 }
         drop && /^\.codex\/hooks\.json text eol=lf$/ { drop = 0; next }
         !drop { print }' .gitattributes > .gitattributes.tmp && mv .gitattributes.tmp .gitattributes
  fi
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

# Share mode: what may reach the remote.
SHARE=$(conf SHARE)
SHARE=${SHARE_ARG:-${SHARE:-agent}}
set_conf SHARE "$SHARE"
case "$SHARE" in all|agent) SHARE_AGENT=yes ;; *) SHARE_AGENT=no ;; esac
case "$SHARE" in all|learning) SHARE_LEARNING=yes ;; *) SHARE_LEARNING=no ;; esac
say "share mode: $SHARE (agent files pushed: $SHARE_AGENT, learning docs pushed: $SHARE_LEARNING)"

# .claude/skills: a link, or a copy where symlinks fail (Windows).
if [ -d .claude/skills ] && [ ! -L .claude/skills ] && [ "$(conf SKILLS_LINK)" != "copy" ]; then
  note ".claude/skills is a real folder: move its own skills into .agents/skills, then run: sh .agents/kit/sync-skills.sh"
elif [ ! -L .claude/skills ]; then
  sh .agents/kit/sync-skills.sh | sed 's/^/  /'
fi

# Ignore and line-ending rules. Shared rules go in .gitignore and
# .gitattributes (committed, so teammates get them). Rules for local-only
# files go in .git/info/ (never committed, so nothing reaches the remote).
EXCLUDE=$(git rev-parse --git-path info/exclude)
ATTRIBUTES=$(git rev-parse --git-path info/attributes)
LEARNING_DIR=$(conf LEARNING_DIR)
LEDGER=$(conf LEDGER)
remove_legacy_rules
local_rules=""
shared_rules=""
if [ "$SHARE_AGENT" = no ]; then
  local_rules="AGENTS.md"
  for pointer in $(conf POINTER_FILES); do local_rules="$local_rules
$pointer"; done
  local_rules="$local_rules
/DECISIONS.md
/PLAN.md
/.agents/
/.claude/
/.codex/
/.githooks/"
  [ -n "$LEDGER" ] && local_rules="$local_rules
/$LEDGER"
fi
if [ -n "$LEARNING_DIR" ] && [ "$SHARE_LEARNING" = no ]; then
  if [ "$SHARE_AGENT" = yes ]; then
    shared_rules="/$LEARNING_DIR/"
  else
    local_rules="$local_rules
/$LEARNING_DIR/"
  fi
fi
write_block .gitignore "$shared_rules"
write_block "$EXCLUDE" "$local_rules"
lf_rules=$(grep -v '^#' "$T/config/gitattributes")
if [ "$SHARE_AGENT" = yes ]; then
  write_block .gitattributes "$lf_rules"
  write_block "$ATTRIBUTES" ""
else
  write_block .gitattributes ""
  write_block "$ATTRIBUTES" "$lf_rules"
fi
say "wrote ignore and line-ending rules for share mode $SHARE"

# Files git already tracks are not affected by ignore rules: stop tracking
# whatever this mode keeps local (the files stay on disk).
agent_paths="AGENTS.md :(glob)**/AGENTS.md DECISIONS.md PLAN.md .agents .claude .codex .githooks"
for pointer in $(conf POINTER_FILES); do agent_paths="$agent_paths $pointer :(glob)**/$pointer"; done
[ -n "$LEDGER" ] && agent_paths="$agent_paths $LEDGER"
if [ "$SHARE_AGENT" = no ]; then
  set -f  # the pathspecs contain ** for git, not for the shell
  # shellcheck disable=SC2086  # pathspecs, one per word
  tracked=$(git ls-files -- $agent_paths | head -5 | tr '\n' ' ')
  set +f
  [ -z "$tracked" ] || note "agent files are tracked but mode $SHARE keeps them local ($tracked...): run  git rm -r --cached -q --ignore-unmatch -- $agent_paths  then commit"
fi
if [ -n "$LEARNING_DIR" ] && [ "$SHARE_LEARNING" = no ] && [ -n "$(git ls-files -- "$LEARNING_DIR" | head -1)" ]; then
  note "learning docs are tracked but mode $SHARE keeps them local: run  git rm -r --cached -q --ignore-unmatch -- $LEARNING_DIR  then commit"
fi

# Executable bit in git, so macOS and Linux clones of a repo set up on
# Windows still run the hooks. Only when the scripts are shared.
if [ "$SHARE_AGENT" = yes ]; then
  git add --chmod=+x .githooks/pre-commit .agents/kit/*.sh 2>/dev/null &&
    say "staged scripts as executable (git add --chmod=+x)"
fi

if [ -n "$NOTES" ]; then
  echo
  echo "For the agent:$NOTES"
fi
echo
echo "Checks now (failures are expected until the maps are written):"
sh .agents/kit/check.sh || true
