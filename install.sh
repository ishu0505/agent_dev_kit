#!/bin/sh
# Install or upgrade the agent kit in a git repository.
#
# Usage: /path/to/agent_dev_kit/install.sh [--share MODE] [--ci] [--confirm-untrack] [target repo]
#
# Skills: a kit skill is replaced only when the repo never edited it (its
# fingerprint matches .agents/kit/skills.sum). An edited skill, or one the
# repo had before the kit, is kept; the new kit version goes to
# .git/agent-kit/incoming/<skill>/ for the agent to merge. Skills listed in
# OWN_SKILLS (.agents/agent-kit.conf) are never touched.
#
#   --share agent     agent files pushed, learning docs local (default)
#   --share all       agent files and learning docs pushed
#   --share learning  learning docs pushed, agent files local
#   --share none      nothing pushed; everything stays on this machine
#   --ci              also add .github/workflows/agent-kit.yml (the checks in CI)
#   --confirm-untrack print the git rm --cached command even when teammates
#                     committed the agent files a local mode stops sharing
#
# Git hooks: when the repo already uses a hook manager (pre-commit, lefthook,
# husky) or has hooks in .git/hooks, the install leaves core.hooksPath alone
# and prints the lines to add there instead.
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
WANT_CI=no
CONFIRM_UNTRACK=no
while [ $# -gt 0 ]; do
  case "$1" in
    --share) SHARE_ARG=${2:-}; shift 2 ;;
    --share=*) SHARE_ARG=${1#--share=}; shift ;;
    --ci) WANT_CI=yes; shift ;;
    --confirm-untrack) CONFIRM_UNTRACK=yes; shift ;;
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
cp "$T"/kit/*.sh "$T"/kit/*.py "$T"/kit/*.md .agents/kit/
rm -f .agents/kit/writing-style.md  # renamed to writing-style.agentk.md in 0.6
cp "$KIT/VERSION" .agents/kit/VERSION
chmod +x .agents/kit/*.sh
say "updated .agents/kit/ (checks, hooks, helpers, writing style, VERSION)"

# Git hooks: ours are replaced; someone else's are left for the agent to merge.
PRE_LINE='sh "$(git rev-parse --show-toplevel)/.agents/kit/check.sh" --staged --quiet || exit 1'
POST_LINE='sh "$(git rev-parse --show-toplevel)/.agents/kit/queue.sh" add HEAD || true'
for hook in pre-commit post-commit; do
  if [ ! -f ".githooks/$hook" ] || grep -q 'agents/kit/' ".githooks/$hook"; then
    cp "$T/githooks/$hook" ".githooks/$hook"
    chmod +x ".githooks/$hook"
    say "updated .githooks/$hook"
  else
    line=$PRE_LINE; [ "$hook" = post-commit ] && line=$POST_LINE
    note ".githooks/$hook already exists: add the line  $line"
  fi
done
hooks_path=$(git config core.hooksPath || true)
managers=""
[ -f .pre-commit-config.yaml ] && managers="$managers pre-commit"
for file in lefthook.yml lefthook.yaml .lefthook.yml; do [ -f "$file" ] && managers="$managers lefthook"; done
[ -d .husky ] && managers="$managers husky"
own_hooks=""
if [ -z "$hooks_path" ]; then
  for hook in "$(git rev-parse --git-path hooks)"/*; do
    [ -f "$hook" ] || continue
    case "$hook" in *.sample) ;; *) own_hooks="$own_hooks $(basename "$hook")" ;; esac
  done
fi
if [ "$hooks_path" = ".githooks" ]; then
  :
elif [ -z "$hooks_path" ] && [ -z "$managers$own_hooks" ]; then
  git config core.hooksPath .githooks
  say "set git config core.hooksPath .githooks (this clone)"
else
  # Taking over core.hooksPath would silently switch the repo's own hooks off.
  for manager in $managers; do
    case "$manager" in
      pre-commit) note "this repo uses the pre-commit framework, so core.hooksPath stays as it is. Add to .pre-commit-config.yaml:
    - repo: local
      hooks:
        - id: agent-kit-check
          name: agent-kit check
          entry: sh .agents/kit/check.sh --staged --quiet
          language: system
          pass_filenames: false
          always_run: true
        - id: agent-kit-queue
          name: agent-kit catch-up queue
          entry: sh .agents/kit/queue.sh add HEAD
          language: system
          pass_filenames: false
          always_run: true
          stages: [post-commit]
  then run: pre-commit install --hook-type pre-commit --hook-type post-commit" ;;
      lefthook) note "this repo uses lefthook, so core.hooksPath stays as it is. Add to lefthook.yml:
    pre-commit:
      commands:
        agent-kit:
          run: sh .agents/kit/check.sh --staged --quiet
    post-commit:
      commands:
        agent-kit:
          run: sh .agents/kit/queue.sh add HEAD
  then run: lefthook install" ;;
      husky) note "this repo uses husky, so core.hooksPath stays as it is. Add the line  $PRE_LINE  to .husky/pre-commit, and  $POST_LINE  to .husky/post-commit" ;;
    esac
  done
  if [ -n "$hooks_path" ] && [ -z "$managers" ]; then
    note "core.hooksPath is $hooks_path: add the line  $PRE_LINE  to its pre-commit, and  $POST_LINE  to its post-commit"
  elif [ -n "$own_hooks" ] && [ -z "$managers" ]; then
    note "this clone has its own hooks in .git/hooks ($own_hooks ), so core.hooksPath stays as it is (setting it would switch them off). Either add the line  $PRE_LINE  to .git/hooks/pre-commit and  $POST_LINE  to .git/hooks/post-commit, or move those hooks into .githooks/ and run: git config core.hooksPath .githooks"
  fi
fi

# Repo-owned: created once, never overwritten.
create_if_missing "$T/config/agent-kit.conf" .agents/agent-kit.conf || true
grep -q '^OWN_SKILLS=' .agents/agent-kit.conf ||
  printf '\n# Skills the repo owns: the kit never replaces them, even if they share\n# a name with a kit skill (e.g. "lineage scaffold").\nOWN_SKILLS=""\n' >> .agents/agent-kit.conf
create_if_missing "$T/config/codex-hooks.json" .codex/hooks.json || true
if ! create_if_missing "$T/config/claude-settings.json" .claude/settings.json; then
  grep -q 'agents/kit/stop-hook.sh' .claude/settings.json ||
    note ".claude/settings.json exists: merge the Stop hook from $T/config/claude-settings.json (and remove any older docs hook)"
  grep -q 'agents/kit/session-start.sh' .claude/settings.json ||
    note ".claude/settings.json exists: merge the SessionStart hook from $T/config/claude-settings.json"
fi
grep -q 'agents/kit/stop-hook.sh' .codex/hooks.json ||
  note ".codex/hooks.json exists: merge the Stop hook from $T/config/codex-hooks.json"

# Skills: replace only what the repo never edited.
skill_sum() {  # skill_sum <folder>: one fingerprint for every file in a skill
  (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r file; do
    printf '%s %s\n' "$file" "$(cksum < "$file")"; done) | cksum | cut -d' ' -f1
}
SUMS=.agents/kit/skills.sum   # <skill> <fingerprint installed, or -> <fingerprint of that kit version>
INCOMING="$(git rev-parse --git-dir)/agent-kit/incoming"
recorded() {  # recorded <skill> <field>: from skills.sum; empty when not recorded
  [ -f "$SUMS" ] || return 0
  awk -v n="$1" -v f="$2" '$1 == n { print $f; exit }' "$SUMS"
}
NEW_SUMS=""
remember() { NEW_SUMS="$NEW_SUMS$1 $2 $3
"; }
rm -rf "$INCOMING"
for skill in "$T"/skills/*/; do
  name=$(basename "$skill")
  dest=".agents/skills/$name"
  kit_sum=$(skill_sum "$skill")
  case " $(conf OWN_SKILLS) " in
    *" $name "*) say "kept .agents/skills/$name (in OWN_SKILLS)"; continue ;;
  esac
  installed=$(recorded "$name" 2); last_kit=$(recorded "$name" 3)
  current=""; [ -d "$dest" ] && current=$(skill_sum "$dest")
  if [ -z "$current" ] || [ "$current" = "$kit_sum" ] ||
     { [ -n "$installed" ] && [ "$installed" != "-" ] && [ "$current" = "$installed" ]; }; then
    rm -rf "$dest" && cp -R "$skill" "$dest"
    remember "$name" "$kit_sum" "$kit_sum"
    say "updated $dest"
  elif [ "$kit_sum" = "$last_kit" ]; then
    remember "$name" "${installed:--}" "$kit_sum"
    say "kept $dest (edited here; the kit has no newer version)"
  else
    mkdir -p "$INCOMING" && cp -R "$skill" "$INCOMING/$name"
    remember "$name" "${installed:--}" "$kit_sum"
    if [ -z "$installed" ] || [ "$installed" = "-" ]; then
      note "$dest is not the kit's version (the repo had its own, or edited it before 0.4). Kept it. If it is the repo's own, add $name to OWN_SKILLS in .agents/agent-kit.conf. If not, merge the kit version from $INCOMING/$name/ into it"
    else
      note "$dest was edited here and the kit has a newer version. Kept yours. Merge the new kit version from $INCOMING/$name/ (see CHANGELOG.md), keeping the repo's additions"
    fi
  fi
done
printf '%s' "$NEW_SUMS" > "$SUMS"
say "recorded skill fingerprints in $SUMS"

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
DECISIONS_DIR=$(conf DECISIONS_DIR)
DOC_SUFFIX=$(conf DOC_SUFFIX)
KIT_MD=${DOC_SUFFIX:-.md}  # kit docs: README.agentk.md, DECISIONS.agentk.md (empty: kit 0.5 names)
remove_legacy_rules
local_rules=""
shared_rules=""
if [ "$SHARE_AGENT" = no ]; then
  local_rules="AGENTS.md"
  for pointer in $(conf POINTER_FILES); do local_rules="$local_rules
$pointer"; done
  local_rules="$local_rules
/DECISIONS$KIT_MD
/PLAN$KIT_MD
/.agents/
/.claude/
/.codex/
/.githooks/"
  [ -n "$LEDGER" ] && local_rules="$local_rules
/$LEDGER"
  [ -n "$DECISIONS_DIR" ] && local_rules="$local_rules
/${DECISIONS_DIR%/}/"
  if [ -n "$DOC_SUFFIX" ]; then  # every doc the kit writes, wherever it is
    local_rules="$local_rules
*$DOC_SUFFIX"
    # Share mode learning still pushes the learning docs.
    [ "$SHARE_LEARNING" = yes ] && [ -n "$LEARNING_DIR" ] && local_rules="$local_rules
!/$LEARNING_DIR/**"
  fi
fi
if [ "$SHARE_AGENT" = yes ]; then
  # Files each person keeps for themselves (Claude Code writes these).
  shared_rules=".claude/settings.local.json
.claude/*.local.*
CLAUDE.local.md"
fi
if [ -n "$LEARNING_DIR" ] && [ "$SHARE_LEARNING" = no ]; then
  if [ "$SHARE_AGENT" = yes ]; then
    shared_rules="$shared_rules
/$LEARNING_DIR/"
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
agent_paths="AGENTS.md :(glob)**/AGENTS.md DECISIONS$KIT_MD PLAN$KIT_MD .agents .claude .codex .githooks"
for pointer in $(conf POINTER_FILES); do agent_paths="$agent_paths $pointer :(glob)**/$pointer"; done
[ -n "$LEDGER" ] && agent_paths="$agent_paths $LEDGER"
[ -n "$DECISIONS_DIR" ] && agent_paths="$agent_paths $DECISIONS_DIR"
[ -n "$DOC_SUFFIX" ] && agent_paths="$agent_paths :(glob)**/*$DOC_SUFFIX"
[ -n "$DOC_SUFFIX" ] && [ "$SHARE_LEARNING" = yes ] && [ -n "$LEARNING_DIR" ] && agent_paths="$agent_paths :(exclude)$LEARNING_DIR"
if [ "$SHARE_AGENT" = no ]; then
  set -f  # the pathspecs contain ** for git, not for the shell
  # shellcheck disable=SC2086  # pathspecs, one per word
  tracked=$(git ls-files -- $agent_paths | head -5 | tr '\n' ' ')
  # shellcheck disable=SC2086
  others=$(git log --format=%ae -- $agent_paths 2>/dev/null | sort -u | grep -v -x -F "$(git config user.email || echo '<none>')" | head -3 | tr '\n' ' ')
  set +f
  if [ -n "$tracked" ] && [ -n "$others" ] && [ "$CONFIRM_UNTRACK" = no ]; then
    echo
    echo "WARNING: other people committed these agent files ($others)."
    echo "  Mode $SHARE stops tracking them. When that commit is pushed, the files are"
    echo "  DELETED for every teammate who pulls it (they stay on this machine only)."
    echo "  If the team should keep them, use --share agent or --share all instead."
    echo "  If the team agreed, run the install again with --confirm-untrack to get the command."
    note "agent files are tracked and teammates committed them: ask the user before untracking (see the WARNING above)"
  elif [ -n "$tracked" ]; then
    note "agent files are tracked but mode $SHARE keeps them local ($tracked...): run  git rm -r --cached -q --ignore-unmatch -- $agent_paths  then commit"
  fi
fi
if [ -n "$LEARNING_DIR" ] && [ "$SHARE_LEARNING" = no ] && [ -n "$(git ls-files -- "$LEARNING_DIR" | head -1)" ]; then
  note "learning docs are tracked but mode $SHARE keeps them local: run  git rm -r --cached -q --ignore-unmatch -- $LEARNING_DIR  then commit"
fi

# Executable bit in git, so macOS and Linux clones of a repo set up on
# Windows still run the hooks. Only when the scripts are shared.
if [ "$SHARE_AGENT" = yes ]; then
  git add --chmod=+x .githooks/pre-commit .githooks/post-commit .agents/kit/*.sh 2>/dev/null &&
    say "staged scripts as executable (git add --chmod=+x)"
fi

# CI: the same checks on every push and pull request.
if [ "$WANT_CI" = yes ]; then
  if [ "$SHARE_AGENT" = yes ]; then
    create_if_missing "$T/ci/github-actions.yml" .github/workflows/agent-kit.yml ||
      say "kept .github/workflows/agent-kit.yml"
  else
    note "--ci skipped: mode $SHARE keeps the kit local, so CI has no check.sh to run"
  fi
fi

if [ -n "$NOTES" ]; then
  echo
  echo "For the agent:$NOTES"
fi
echo
echo "Checks now (failures are expected until the maps are written):"
sh .agents/kit/check.sh || true
