#!/bin/sh
# Agent kit checks: the agent maps stay short and true, and the setup
# around them (skills, hooks, git) works on every clone.
#
# Usage: .agents/kit/check.sh [--quiet]
# Reads .agents/agent-kit.conf. Prints each failure with its fix and exits 1
# when anything fails. Needs only sh, git, grep, awk and sed, so it works in a
# repo of any language. Installed by agent_dev_kit; do not edit in a target
# repo (install.sh --upgrade overwrites it).

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "agent-kit: not inside a git repository"; exit 1; }
cd "$ROOT" || exit 1

# Defaults; the repo's config overrides them.
UNITS=""
UNIT_PARENTS=""
SKILLS_LINK="symlink"
SHARE="agent"
TOP_MAP_MAX=70
UNIT_MAP_MAX=40
POINTER_FILES="CLAUDE.md"
LEDGER=""
LEARNING_DIR="learning_docs"
SKIP_DIRS="node_modules .venv venv vendor target build dist out bin obj"
CONF=".agents/agent-kit.conf"
if [ -f "$CONF" ]; then
  . "./$CONF"
else
  echo "FAIL $CONF is missing"
  echo "     fix: run agent_dev_kit/install.sh on this repo"
  exit 1
fi

FAILS=0
MAPS=0
fail() {
  FAILS=$((FAILS + 1))
  printf 'FAIL %s\n     fix: %s\n' "$1" "$2"
}

is_skipped() {  # is_skipped <folder name>
  case "$1" in .*|_*) return 0 ;; esac
  [ "$1" = "$LEARNING_DIR" ] && return 0
  for skip in $SKIP_DIRS; do [ "$1" = "$skip" ] && return 0; done
  return 1
}

unit_folders() {  # every unit: listed in UNITS, or a child of a UNIT_PARENTS folder
  for unit in $UNITS; do [ -d "$unit" ] && echo "${unit%/}"; done
  for parent in $UNIT_PARENTS; do
    [ -d "$parent" ] || continue
    for child in "${parent%/}"/*/; do
      [ -d "$child" ] || continue
      name=$(basename "$child")
      is_skipped "$name" || echo "${child%/}"
    done
  done
}

top_folders() {  # first-level folders that have their own map
  for child in */; do
    [ -f "${child}AGENTS.md" ] || continue
    is_skipped "${child%/}" || echo "${child%/}"
  done
}

mapped_paths() {  # mapped_paths <AGENTS.md>: paths the map names
  awk '
    { sub(/\r$/, "") }
    function ticked(text) { if (match(text, /`[^`]+`/)) return substr(text, RSTART + 1, RLENGTH - 2); return "" }
    function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
    /^#/ { section = $0; header = 0; next }
    !/^\|/ { header = 0 }
    /^- `/ && section ~ /Further reading/ { print ticked($0) }
    /^\|/ {
      if ($0 ~ /^[|: -]+$/) next
      n = split($0, cells, "|")
      if (!header) { header = 1; for (i = 2; i < n; i++) head[i] = trim(cells[i]); next }
      if (head[2] == "Path" && ticked(cells[2]) != "") print ticked(cells[2])
      for (i = 2; i < n; i++) if (head[i] == "Read first") {
        rest = cells[i]
        while (match(rest, /`[^`]+`/)) { print substr(rest, RSTART + 1, RLENGTH - 2); rest = substr(rest, RSTART + RLENGTH) }
      }
    }' "$1"
}

check_map() {  # check_map <folder> <max lines>
  folder=$1
  max=$2
  map="$folder/AGENTS.md"
  MAPS=$((MAPS + 1))
  lines=$(wc -l < "$map" | tr -d ' ')
  [ "$lines" -le "$max" ] || fail "$map has $lines lines (max $max)" \
    "move detail into the README it points to; keep the map"
  mapped_paths "$map" | while IFS= read -r path; do
    [ -n "$path" ] || continue
    path=${path%/}
    # A mapped path may be a glob (src/*View.svelte); unquoted on purpose.
    set -- "$folder"/$path
    [ -e "$1" ] || echo "$path"
  done > "$TMP_MISSING"
  while IFS= read -r missing; do
    fail "$map names a missing path: $missing" "fix the path or remove the row"
  done < "$TMP_MISSING"
  for pointer in $POINTER_FILES; do
    if ! grep -q '@AGENTS.md' "$folder/$pointer" 2>/dev/null; then
      fail "$folder/$pointer does not import the map" "create it containing exactly: @AGENTS.md"
    fi
  done
}

check_maps() {
  if [ ! -f AGENTS.md ]; then
    fail "AGENTS.md is missing at the repo root" "write the root map (BOOTSTRAP.md, phase 4)"
    return
  fi
  check_map . "$TOP_MAP_MAX"
  for folder in $(top_folders); do check_map "$folder" "$TOP_MAP_MAX"; done
  for unit in $(unit_folders); do
    for needed in README.md AGENTS.md; do
      [ -f "$unit/$needed" ] || fail "$unit has no $needed" "create it with the scaffold skill"
    done
    if [ -f "$unit/AGENTS.md" ] && ! top_folders | grep -qx "$unit"; then
      check_map "$unit" "$UNIT_MAP_MAX"
    fi
  done
}

tree_sum() {  # tree_sum <folder>: one checksum line per file, for comparing copies
  (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r file; do
    printf '%s %s\n' "$file" "$(cksum < "$file")"; done)
}

check_skills() {
  [ -d .agents/skills ] || return
  if [ -f .claude/skills ]; then
    # A symlink checked out where links are off (Windows) becomes a text file.
    fail ".claude/skills is a plain file: this clone cannot use symlinks" \
      "set SKILLS_LINK=\"copy\" in .agents/agent-kit.conf, run: rm .claude/skills && sh .agents/kit/sync-skills.sh, and commit"
  elif [ ! -e .claude/skills ]; then
    [ -d .claude ] && fail ".claude/skills is missing, so Claude Code sees no skills" "run: sh .agents/kit/sync-skills.sh"
  elif [ "$SKILLS_LINK" = "copy" ]; then
    [ "$(tree_sum .claude/skills)" = "$(tree_sum .agents/skills)" ] ||
      fail ".claude/skills is out of sync with .agents/skills" \
        "edit skills in .agents/skills only, then run: sh .agents/kit/sync-skills.sh"
  else
    claude=$(cd -P .claude/skills && pwd)
    agents=$(cd -P .agents/skills && pwd)
    [ "$claude" = "$agents" ] || fail ".claude/skills is a copy, not a link to .agents/skills; copies drift" \
      "run: sh .agents/kit/sync-skills.sh (or set SKILLS_LINK=\"copy\" where symlinks do not work)"
  fi
}

agent_paths() {  # pathspecs of every agent file: maps, pointers, lineage, kit folders
  printf '%s\n' AGENTS.md ':(glob)**/AGENTS.md' DECISIONS.md PLAN.md .agents .claude .codex .githooks
  for pointer in $POINTER_FILES; do printf '%s\n' "$pointer" ":(glob)**/$pointer"; done
  [ -z "$LEDGER" ] || printf '%s\n' "$LEDGER"
}

check_share_mode() {  # files reach the remote only when SHARE allows it
  case "$SHARE" in
    agent|all|learning|none) ;;
    *) fail "SHARE=\"$SHARE\" is not a share mode" "set SHARE to agent, all, learning or none in $CONF"; return ;;
  esac
  if [ "$SHARE" = agent ] || [ "$SHARE" = all ]; then
    untracked=$(git ls-files --others --exclude-standard -- .agents .claude .codex .githooks | tr '\n' ' ')
    [ -z "$untracked" ] || fail "agent files are not in git, so a fresh clone lacks them: $untracked" \
      "git add them (put personal files in your global git ignore)"
  else
    set -f  # the pathspecs contain ** for git, not for the shell
    # shellcheck disable=SC2046  # one pathspec per line
    tracked=$(git ls-files -- $(agent_paths) | head -5 | tr '\n' ' ')
    set +f
    [ -z "$tracked" ] || fail "SHARE=$SHARE keeps agent files local, but git tracks or stages: $tracked" \
      "run: git rm -r --cached -q --ignore-unmatch -- $(agent_paths | tr '\n' ' ') (the files stay on disk)"
    { git check-ignore -q AGENTS.md && git check-ignore -q .agents/kit/check.sh; } || fail "agent files are not ignored, so they can be committed by mistake" \
      "run once: sh <agent_dev_kit>/install.sh  (it writes .git/info/exclude for SHARE=$SHARE)"
  fi
}

check_git_setup() {
  # The commit check is active when the hooks folder git uses runs check.sh
  # (.githooks by default; husky or .git/hooks also work), or when the
  # pre-commit framework's config does.
  hooks_dir=$(git config core.hooksPath || true)
  hooks_dir=${hooks_dir:-$(git rev-parse --git-path hooks)}
  if ! grep -qs 'agents/kit/check.sh' "$hooks_dir/pre-commit" &&
     ! grep -qs 'agents/kit/check.sh' .pre-commit-config.yaml; then
    fail "the pre-commit check is not active in this clone" \
      "run once: git config core.hooksPath .githooks"
  fi
  for config in .claude/settings.json .codex/hooks.json; do
    [ -f "$config" ] || continue
    if grep -qF "$ROOT" "$config" ||
       grep -qE '(/Users/|/home/|[A-Za-z]:[\\/]+Users)' "$config"; then
      fail "$config hard-codes a path on this machine" \
        "use \"\$CLAUDE_PROJECT_DIR/...\" or \"\$(git rev-parse --show-toplevel)/...\""
    fi
    for script in $(grep -oE '\.(agents|claude|codex|githooks)/[A-Za-z0-9_./-]+\.(sh|py)' "$config"); do
      [ -f "$script" ] || fail "$config runs $script, which does not exist" "fix the path in $config"
    done
  done
}

check_portability() {  # works on Windows, macOS and Linux clones alike
  eol=$(git check-attr eol -- .agents/kit/check.sh | sed 's/.*: //')
  [ "$eol" = "lf" ] || fail "scripts may get Windows line endings (CRLF), which breaks sh" \
    "add the agent-kit lines from agent_dev_kit/templates/config/gitattributes to .gitattributes"
  for script in .githooks/pre-commit .agents/kit/check.sh .agents/kit/stop-hook.sh .agents/kit/sync-skills.sh; do
    mode=$(git ls-files -s -- "$script" | cut -c1-6)
    [ -z "$mode" ] || [ "$mode" = "100755" ] || fail "$script is not executable in git; macOS and Linux clones skip it" \
      "run: git add --chmod=+x $script"
  done
}

check_learning_docs() {
  [ -n "$LEARNING_DIR" ] || return
  if [ "$SHARE" = all ] || [ "$SHARE" = learning ]; then
    if git check-ignore -q "$LEARNING_DIR/probe.md"; then
      fail "SHARE=$SHARE pushes learning docs, but $LEARNING_DIR/ is git-ignored" \
        "remove the $LEARNING_DIR/ rule from .gitignore or .git/info/exclude (install.sh rewrites its own)"
    fi
    return
  fi
  tracked=$(git ls-files -- "$LEARNING_DIR" | head -3 | tr '\n' ' ')
  [ -z "$tracked" ] || fail "learning docs are tracked or staged: $tracked" \
    "run: git rm -r --cached $LEARNING_DIR (they stay local)"
  git check-ignore -q "$LEARNING_DIR/probe.md" || fail "$LEARNING_DIR/ is not git-ignored" \
    "run: sh <agent_dev_kit>/install.sh  (it writes the ignore rule for SHARE=$SHARE)"
}

check_ledger() {  # every folder beside the ledger has a row with an outcome
  [ -n "$LEDGER" ] && [ -f "$LEDGER" ] || return
  rows=$(awk '
    { sub(/\r$/, "") }
    function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
    /^\|/ && $0 !~ /^[|: -]+$/ {
      n = split($0, cells, "|")
      if (!col) { for (i = 2; i < n; i++) if (trim(cells[i]) == "Outcome") col = i; next }
      if (match(cells[2], /`[^`]+`/)) {
        name = substr(cells[2], RSTART + 1, RLENGTH - 2); sub(/\/.*/, "", name)
        print name "\t" (trim(cells[col]) == "" ? "EMPTY" : "ok")
      }
    }' "$LEDGER")
  for folder in "$(dirname "$LEDGER")"/*/; do
    [ -d "$folder" ] || continue
    name=$(basename "$folder")
    is_skipped "$name" && continue
    row=$(printf '%s\n' "$rows" | awk -F '\t' -v n="$name" '$1 == n { print $2; exit }')
    if [ -z "$row" ]; then
      fail "$name has no row in $LEDGER" "add its row through the lineage skill"
    elif [ "$row" = "EMPTY" ]; then
      fail "$name has no outcome in $LEDGER" "summarise its report, or write: pending: not run yet"
    fi
  done
}

TMP_MISSING=$(mktemp) || exit 1
trap 'rm -f "$TMP_MISSING"' EXIT
check_maps
check_skills
check_share_mode
check_git_setup
check_portability
check_learning_docs
check_ledger

if [ "$FAILS" -gt 0 ]; then
  echo "agent-kit: $FAILS check(s) failed"
  exit 1
fi
[ "$QUIET" = 1 ] || echo "agent-kit: all checks pass ($MAPS maps)"
