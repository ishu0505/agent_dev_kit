#!/bin/sh
# A multi-repo workspace: a folder (not a git repo) that holds several repos
# side by side, e.g. frontend/ and backend/. The kit gives it one map,
# WORKSPACE.agentk.md, that every agent reads, and hooks that check every repo
# with the kit after an agent turn. Nothing is written inside a repo except
# the kit's own install (with your yes) and, for "never install", a note in
# that repo's .git folder, which is never committed or pushed.
#
# Usage (from the workspace folder; the agent-kit skill runs these):
#   sh <kit>/templates/workspace/workspace.sh init [--name <name>] [--meta]
#   sh .agent-workspace/kit/workspace.sh <command>
#
#   init            set up this folder as a workspace (again: refresh the kit
#                   scripts; your files stay), then scan
#   add <url|path> [--as <dir>] [--worktree|--clone|--move]
#                   bring a repo in: a URL is cloned; a local repo becomes a
#                   git worktree (default), a clone, or is moved here
#   scan            find every repo here (also ones you copied or cloned by
#                   hand), refresh the repo table in WORKSPACE.agentk.md, and
#                   list the repos that wait for an answer about the kit
#   repos           one line per repo: <dir> TAB <kit|declined|none|symlink>
#   status          per repo: kit, catch-up queue, other people's commits,
#                   stale learning docs
#   where [<repo>]  the workspaces that hold this repo (default: the current one)
#   decline <dir>   "never install the kit here": a note in <dir>'s .git folder
#   undecline <dir> remove that note
#
# --meta: the workspace folder is itself a git repo. The kit's files there
# are kept out of git with .git/info/exclude.
#
# The registry of workspaces is ${AGENT_KIT_STATE:-~/.agent-kit}/workspaces.
# POSIX sh with git, grep, awk, sed and cksum, like the rest of the kit.

set -u
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
STATE_HOME=${AGENT_KIT_STATE:-$HOME/.agent-kit}
REGISTRY="$STATE_HOME/workspaces"
TAB=$(printf '\t')
REPOS_BEGIN="<!-- agent-kit:repos (written by workspace.sh scan; edit only the Role column) -->"
REPOS_END="<!-- /agent-kit:repos -->"
MARK="agent-kit workspace"

die() { echo "workspace: $1"; [ -n "${2:-}" ] && echo "  fix: $2"; exit 1; }

# The workspace root: the nearest folder up from here with .agent-workspace/.
find_root() {
  d=$(pwd -P)
  while :; do
    [ -f "$d/.agent-workspace/workspace.conf" ] && { echo "$d"; return 0; }
    [ "$d" = / ] || [ "$d" = . ] || [ -z "$d" ] && return 1
    d=$(dirname "$d")
  done
}

# The kit folder: AGENT_KIT_HOME, the path init wrote, or this script's kit.
kit_home() {
  if [ -n "${AGENT_KIT_HOME:-}" ] && [ -f "$AGENT_KIT_HOME/install.sh" ]; then echo "$AGENT_KIT_HOME"; return; fi
  if [ -f "$SELF_DIR/kit-path" ]; then k=$(cat "$SELF_DIR/kit-path"); [ -f "$k/install.sh" ] && { echo "$k"; return; }; fi
  k=$(cd "$SELF_DIR/../.." 2>/dev/null && pwd); [ -f "$k/install.sh" ] && { echo "$k"; return; }
  echo ""
}

common_dir() {  # common_dir <repo>: its shared .git folder, as a real path
  (cd "$1" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)
}

# Repos in the workspace: folders one or two levels down with a .git folder or
# file (a worktree or a submodule), not inside another repo found here.
find_repos() {
  find . -mindepth 2 -maxdepth 3 \( -path './.*' -o -name node_modules \) -prune -o -name .git -print -prune 2>/dev/null |
    sed -e 's|^\./||' -e 's|/\.git$||' | LC_ALL=C sort | while IFS= read -r dir; do
      case "$dir" in */*) [ -e "${dir%/*}/.git" ] && continue ;; esac
      echo "$dir"
    done
}
find_links() {  # repos reached through a symlink: not supported (see scan)
  for d in ./* ./*/*; do
    [ -L "$d" ] && [ -d "$d" ] && git -C "$d" rev-parse --git-dir >/dev/null 2>&1 && echo "${d#./}"
  done
}

conf_of() {  # conf_of <repo> <KEY>: a value from the repo's kit config
  tr -d '\r' < "$1/.agents/agent-kit.conf" 2>/dev/null | sed -n "s/^$2=\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*\$/\1/p" | tail -1
}
status_of() {  # status_of <repo>: kit | declined | none
  if [ -f "$1/.agents/kit/VERSION" ]; then echo kit
  elif [ -f "$(common_dir "$1")/agent-kit/declined" ]; then echo declined
  else echo none; fi
}
kit_label() {  # kit_label <repo>: "kit 0.8.0, own" and the like
  case "$(status_of "$1")" in
    kit) maps=$(conf_of "$1" MAPS); echo "kit $(tr -d '\r\n' < "$1/.agents/kit/VERSION"), ${maps:-own}" ;;
    declined) echo "declined" ;;
    none) echo "none (no answer yet)" ;;
  esac
}
light_map() { echo ".agent-workspace/maps/$(printf '%s' "$1" | sed 's|/|__|g').agentk.md"; }
read_first() {  # read_first <repo>: the file an agent reads before working there
  if [ -f "$1/.agents/kit/VERSION" ] && [ "$(conf_of "$1" MAPS)" = beside ]; then
    suffix=$(conf_of "$1" DOC_SUFFIX); echo "$1/AGENTS${suffix:-.agentk.md}"; return
  fi
  [ -f "$1/AGENTS.md" ] && { echo "$1/AGENTS.md"; return; }
  [ -f "$(light_map "$1")" ] && { light_map "$1"; return; }
  for f in README.md README.rst README.txt README; do [ -f "$1/$f" ] && { echo "$1/$f"; return; }; done
  echo "-"
}
hint_of() {  # hint_of <repo>: team or personal, from the authors of recent commits
  n=$(git -C "$1" log -n 300 --format=%ae 2>/dev/null | LC_ALL=C sort -u | wc -l | tr -d ' ')
  agent_files=""; [ -f "$1/.agents/kit/VERSION" ] || agent_files=$(git -C "$1" ls-files AGENTS.md CLAUDE.md 2>/dev/null)
  if [ "${n:-0}" -gt 1 ] || [ -n "$agent_files" ]; then echo team; else echo personal; fi
}
light_age() {  # light_age <repo>: how many commits the light map is behind, or empty
  map=$(light_map "$1"); [ -f "$map" ] || return 0
  sc=$(sed -n 's/^source_commit:[[:space:]]*\([0-9a-f]*\).*/\1/p' "$map" | head -1)
  [ -n "$sc" ] && git -C "$1" cat-file -e "$sc^{commit}" 2>/dev/null || { echo "?"; return 0; }
  git -C "$1" rev-list --count "$sc..HEAD" 2>/dev/null
}

register() {  # register <root>: add to the registry; drop folders that are gone
  mkdir -p "$STATE_HOME"
  { [ -f "$REGISTRY" ] && cat "$REGISTRY"; echo "$1"; } | while IFS= read -r w; do
    [ -n "$w" ] && [ -f "$w/.agent-workspace/workspace.conf" ] && echo "$w"
  done | awk '!seen[$0]++' > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
}

table() {  # table <old map>: the repo table, keeping the Role the people wrote
  printf '%s\n' "$REPOS_BEGIN" "| Repo | Role | Kit | Read first |" "|---|---|---|---|"
  find_repos | while IFS= read -r repo; do
    role=$(awk -F'|' -v r="\`$repo/\`" '{ c = $2; gsub(/^ +| +$/, "", c) } c == r { v = $3; gsub(/^ +| +$/, "", v); print v; exit }' "$1" 2>/dev/null)
    first=$(read_first "$repo"); [ "$first" = - ] || first="\`$first\`"
    printf '| `%s/` | %s | %s | %s |\n' "$repo" "${role:-_say what it is_}" "$(kit_label "$repo")" "$first"
  done
  echo "$REPOS_END"
}
refresh_table() {  # refresh_table: rewrite the block between the markers in WORKSPACE.agentk.md
  map=WORKSPACE.agentk.md
  [ -f "$map" ] || return 0
  table "$map" > .agent-workspace/table.tmp
  if grep -qF "$REPOS_BEGIN" "$map"; then
    awk -v b="$REPOS_BEGIN" -v e="$REPOS_END" -v f=.agent-workspace/table.tmp '
      $0 == b { while ((getline line < f) > 0) print line; skip = 1; next }
      $0 == e { skip = 0; next } !skip { print }' "$map" > "$map.tmp" && mv "$map.tmp" "$map"
  else
    { cat "$map"; echo; cat .agent-workspace/table.tmp; } > "$map.tmp" && mv "$map.tmp" "$map"
  fi
  rm -f .agent-workspace/table.tmp
}

cmd_scan() {
  refresh_table
  printf '%-24s %-24s %-9s %s\n' REPO KIT HINT "READ FIRST"
  find_repos | while IFS= read -r repo; do
    first=$(read_first "$repo")
    age=$(light_age "$repo")
    [ -n "$age" ] && [ "$age" != 0 ] && first="$first ($age commits behind: refresh the light map)"
    printf '%-24s %-24s %-9s %s\n' "$repo" "$(kit_label "$repo")" "$(hint_of "$repo")" "$first"
  done
  find_links | while IFS= read -r link; do
    printf '%-24s %s\n' "$link" "a symlink: not supported (the wrong workspace map would load). Fix: rm $link, then: sh .agent-workspace/kit/workspace.sh add <the real path> --as $link --worktree"
  done
  waiting=$(find_repos | while IFS= read -r repo; do [ "$(status_of "$repo")" = none ] && echo "$repo"; done)
  if [ -n "$waiting" ]; then
    echo
    echo "Waiting for an answer about the kit: $(printf '%s' "$waiting" | tr '\n' ' ')"
    echo "Ask for each: install (beside for a team repo, own for a personal one) / not now / never (workspace.sh decline <dir>)."
  fi
}

cmd_repos() {
  find_repos | while IFS= read -r repo; do printf '%s\t%s\n' "$repo" "$(status_of "$repo")"; done
  find_links | while IFS= read -r link; do printf '%s\tsymlink\n' "$link"; done
}

cmd_status() {
  printf '%-24s %-24s %-8s %-8s %s\n' REPO KIT QUEUE PULLED "STALE LEARNING"
  find_repos | while IFS= read -r repo; do
    q=-; p=-; s=-
    if [ "$(status_of "$repo")" = kit ]; then
      q=$(cd "$repo" && sh .agents/kit/queue.sh count 2>/dev/null)
      [ -f "$repo/.agents/kit/pulled.sh" ] && p=$(cd "$repo" && sh .agents/kit/pulled.sh count 2>/dev/null)
      f="$(common_dir "$repo")/agent-kit/stale-learning"; s=0; [ -s "$f" ] && s=$(wc -l < "$f" | tr -d ' ')
    fi
    printf '%-24s %-24s %-8s %-8s %s\n' "$repo" "$(kit_label "$repo")" "${q:--}" "${p:--}" "$s"
  done
}

cmd_where() {
  target=$(common_dir "${1:-.}") || die "${1:-.} is not a git repository"
  [ -n "$target" ] || die "${1:-.} is not a git repository"
  [ -f "$REGISTRY" ] || { echo "no workspaces registered yet"; return 0; }
  while IFS= read -r w; do
    [ -f "$w/.agent-workspace/workspace.conf" ] || continue
    (cd "$w" && find_repos) | while IFS= read -r repo; do
      [ "$(common_dir "$w/$repo")" = "$target" ] && printf '%s\t%s\n' "$w" "$repo"
    done
  done < "$REGISTRY"
}

cmd_decline() {
  [ -n "${1:-}" ] && [ -e "$1/.git" ] || die "${1:-<dir>} is not a repo in this workspace" "sh .agent-workspace/kit/workspace.sh repos"
  dir=$(common_dir "$1")/agent-kit; mkdir -p "$dir"
  echo "Never install the agent kit in this repo (answered on $(date +%Y-%m-%d) in workspace $(pwd -P))." > "$dir/declined"
  echo "noted in $1's .git folder (never committed): the kit is not installed there; agents read it without writing kit files"
  refresh_table
}
cmd_undecline() {
  [ -n "${1:-}" ] && [ -e "$1/.git" ] || die "${1:-<dir>} is not a repo in this workspace"
  rm -f "$(common_dir "$1")/agent-kit/declined" && echo "removed the note: the next scan asks about $1 again"
  refresh_table
}

cmd_add() {
  src=""; as=""; how=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --as) [ $# -ge 2 ] || die "--as needs a folder name"; as=$2; shift 2 ;;
      --worktree|--clone|--move) how=${1#--}; shift ;;
      *) src=$1; shift ;;
    esac
  done
  [ -n "$src" ] || die "add needs a git URL or a local repo path" "workspace.sh add <url|path> [--as <dir>]"
  if [ -d "$src" ] && git -C "$src" rev-parse --git-dir >/dev/null 2>&1; then
    src=$(cd "$src" && git rev-parse --show-toplevel)
    dest=${as:-$(basename "$src")}
    [ -e "$dest" ] && die "$dest already exists here" "choose another name with --as <dir>"
    case "${how:-worktree}" in
      worktree)
        git -C "$src" worktree add --detach "$(pwd -P)/$dest" >/dev/null 2>&1 ||
          die "git worktree add failed for $src" "try --clone, or run: git -C $src worktree add --detach $(pwd -P)/$dest"
        echo "added $dest/ as a git worktree of $src (one .git, its own folder; detached at $(git -C "$dest" rev-parse --short HEAD))"
        echo "  pick a branch there: git -C $dest switch -c <new branch>   (a branch can be checked out in one worktree only)" ;;
      clone)
        git clone -q "$src" "$dest" || die "git clone failed for $src"
        echo "added $dest/ as an independent clone of $src" ;;
      move)
        mv "$src" "$dest" || die "could not move $src"
        git -C "$dest" worktree repair >/dev/null 2>&1
        echo "moved $src to $dest/" ;;
    esac
  else
    [ -z "$how" ] || [ "$how" = clone ] || die "--$how needs a local repo, not a URL"
    dest=${as:-$(basename "$src" .git)}
    [ -e "$dest" ] && die "$dest already exists here" "choose another name with --as <dir>"
    git clone -q "$src" "$dest" || die "git clone failed for $src"
    echo "cloned $src into $dest/"
  fi
  others=$(cmd_where "$(pwd -P)/$dest" | awk -F"$TAB" -v me="$(pwd -P)" '$1 != me { print $1 }' | tr '\n' ' ')
  [ -n "$others" ] && echo "  this repo is also in: $others"
  echo "  kit: $(kit_label "$dest"); hint: $(hint_of "$dest"). Ask: install (beside for a team repo, own for a personal one) / not now / never"
  refresh_table
}

write_new() {  # write_new <path> <content file>: create it only when missing
  if [ -e "$1" ]; then return 1; fi
  mkdir -p "$(dirname "$1")"; cp "$2" "$1"; echo "created $1"
}

cmd_init() {
  name=""; meta=no
  while [ $# -gt 0 ]; do
    case "$1" in
      --name) [ $# -ge 2 ] || die "--name needs a value"; name=$2; shift 2 ;;
      --meta) meta=yes; shift ;;
      *) die "unknown option $1" "workspace.sh init [--name <name>] [--meta]" ;;
    esac
  done
  if git rev-parse --git-dir >/dev/null 2>&1 && [ "$meta" = no ]; then
    die "this folder is inside a git repo ($(git rev-parse --show-toplevel))" \
      "run init in the folder that holds your repos, or add --meta when this repo is the workspace (its files stay out of git)"
  fi
  kit=$(kit_home); [ -n "$kit" ] || die "cannot find the agent kit" "set AGENT_KIT_HOME to the agent_dev_kit folder"
  T="$kit/templates"
  name=${name:-$(basename "$(pwd -P)")}
  mkdir -p .agent-workspace/kit .agent-workspace/maps
  cp "$T/workspace/workspace.sh" "$T/workspace/ws-hook.sh" "$T/kit/lib.sh" "$T/kit/docs_reminder.py" .agent-workspace/kit/
  cp "$kit/VERSION" .agent-workspace/kit/VERSION
  echo "$kit" > .agent-workspace/kit/kit-path
  chmod +x .agent-workspace/kit/*.sh
  echo "updated .agent-workspace/kit/ (workspace scripts, VERSION)"
  write_new .agent-workspace/workspace.conf "$T/workspace/workspace.conf" || true
  sed "s/<name>/$(printf '%s' "$name" | sed 's/[&/\]/\\&/g')/" "$T/workspace/WORKSPACE.md" > .agent-workspace/map.tmp
  write_new WORKSPACE.agentk.md .agent-workspace/map.tmp || true
  rm -f .agent-workspace/map.tmp
  made=""
  printf '<!-- %s: written by workspace.sh init -->\n@WORKSPACE.agentk.md\n' "$MARK" > .agent-workspace/p.tmp
  if write_new CLAUDE.md .agent-workspace/p.tmp; then made="$made CLAUDE.md"
  elif ! grep -q 'WORKSPACE.agentk.md' CLAUDE.md; then
    if ! grep -qs 'WORKSPACE.agentk.md' CLAUDE.local.md; then
      { [ -s CLAUDE.local.md ] && { cat CLAUDE.local.md; echo; }; cat .agent-workspace/p.tmp; } > .agent-workspace/l.tmp &&
        mv .agent-workspace/l.tmp CLAUDE.local.md
      echo "CLAUDE.md here is not the kit's: added @WORKSPACE.agentk.md to CLAUDE.local.md instead"
      made="$made CLAUDE.local.md"
    fi
  fi
  printf '<!-- %s: written by workspace.sh init -->\n# Workspace\n\nThis folder holds several git repos. Read `WORKSPACE.agentk.md` before you\nwork: it lists the repos, what each one is, the contracts between them and\nthe rules. Inside a repo, that repo'"'"'s own AGENTS.md comes first.\n' "$MARK" > .agent-workspace/p.tmp
  if write_new AGENTS.md .agent-workspace/p.tmp; then made="$made AGENTS.md"
  elif ! grep -q 'WORKSPACE.agentk.md' AGENTS.md; then
    echo "AGENTS.md here is not the kit's: kept it. Add a line that says to read WORKSPACE.agentk.md, if you want Codex to find it"
  fi
  rm -f .agent-workspace/p.tmp
  write_new .claude/settings.json "$T/workspace/claude-settings.json" && made="$made .claude/settings.json" ||
    grep -q 'ws-hook.sh' .claude/settings.json || echo "NOTE .claude/settings.json exists: merge the hooks from $T/workspace/claude-settings.json"
  write_new .codex/hooks.json "$T/workspace/codex-hooks.json" && made="$made .codex/hooks.json" ||
    grep -q 'ws-hook.sh' .codex/hooks.json || echo "NOTE .codex/hooks.json exists: merge the hooks from $T/workspace/codex-hooks.json"
  if [ "$meta" = yes ]; then
    exclude=$(git rev-parse --git-path info/exclude)
    mkdir -p "$(dirname "$exclude")"
    for path in /WORKSPACE.agentk.md /.agent-workspace/ $made; do
      case "$path" in /*) ;; *) path="/$path" ;; esac
      grep -qxF "$path" "$exclude" 2>/dev/null || echo "$path" >> "$exclude"
    done
    echo "kept the workspace files out of this repo's git (.git/info/exclude)"
  fi
  register "$(pwd -P)"
  echo "registered $(pwd -P) in $REGISTRY"
  echo
  cmd_scan
}

cmd=${1:-scan}; [ $# -gt 0 ] && shift
ORIG=$(pwd -P)
if [ "$cmd" = where ]; then  # a path is relative to where you ran it
  target=$(cd "$ORIG" && cd "${1:-.}" 2>/dev/null && pwd -P) || die "${1:-.} is not a folder"
  set -- "$target"
fi
if [ "$cmd" != init ] && [ "$cmd" != where ]; then
  root=$(find_root) || die "not inside a workspace" "run: sh <agent_dev_kit>/templates/workspace/workspace.sh init  (in the folder that holds your repos)"
  cd "$root" || exit 1
fi
case "$cmd" in
  init) cmd_init "$@" ;;
  add) cmd_add "$@" ;;
  scan) cmd_scan ;;
  repos) cmd_repos ;;
  status) cmd_status ;;
  where) cmd_where "$@" ;;
  decline) cmd_decline "$@" ;;
  undecline) cmd_undecline "$@" ;;
  *) echo "usage: workspace.sh init|add|scan|repos|status|where|decline|undecline (see the top of this file)"; exit 2 ;;
esac
