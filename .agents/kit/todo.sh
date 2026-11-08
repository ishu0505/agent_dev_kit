#!/bin/sh
# Todo list: ideas and follow-ups to do in a later session, kept in
# TODO<DOC_SUFFIX> at the repo root, one "## T-NNN: <title>" block per item.
# It follows SHARE like every kit doc: committed or local.
#
# Usage: sh .agents/kit/todo.sh add <category> <title>   append an item; prints its ID
#        sh .agents/kit/todo.sh list [category|open|doing]  id, category, status, title (tab-separated)
#        sh .agents/kit/todo.sh show <id>                print the item's block
#        sh .agents/kit/todo.sh set <id> <open|doing>    change its status
#        sh .agents/kit/todo.sh done <id>                delete the item (done means gone)
#        sh .agents/kit/todo.sh refs                     id and path of every ref (tab-separated)
#        sh .agents/kit/todo.sh count                    one summary line; empty when none
#
# An ID is T-007, t-7 or 7. The script owns IDs, Status and deletion; the
# todo skill writes From, Refs and notes. A deleted ID is never reused.
# Installed by agent_dev_kit; do not edit here.

KIT_DIR=$(cd "$(dirname "$0")" && pwd)  # before cd: $0 may be relative
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "todo: not inside a git repository"; exit 1; }
cd "$ROOT" || exit 1
DOC_SUFFIX=".agentk.md"
TODO_CATEGORIES="task bug chore experiment"
. "$KIT_DIR/lib.sh" && load_conf
TODO_FILE="TODO${DOC_SUFFIX:-.md}"

stop() {  # stop <message> [exit code]
  echo "todo: $1"; exit "${2:-1}"
}
item_id() {  # item_id <T-007 | t-7 | 7>: the ID as written in the file
  digits=$(printf '%s' "$1" | sed 's/^[Tt]-//')
  case "$digits" in ''|*[!0-9]*) stop "\"$1\" is not an ID; see them with: sh .agents/kit/todo.sh list" 2 ;; esac
  # Leading zeros dropped first: printf would read 008 as octal.
  printf 'T-%03d' "$(printf '%s' "$digits" | sed 's/^0*\(.\)/\1/')"
}
items() {  # one line per item: id, category, status, title (tab-separated)
  [ -f "$TODO_FILE" ] || return 0
  awk 'BEGIN { OFS = "\t" }
    { sub(/\r$/, "") }
    function flush() { if (id != "") print id, category, status, title }
    /^## T-[0-9]+:/ {
      flush(); id = $2; sub(/:$/, "", id)
      title = $0; sub(/^## T-[0-9]+:[ \t]*/, "", title); category = ""; status = ""; next }
    /^## / { flush(); id = ""; next }
    id != "" && category == "" && /^Category:/ { category = $2 }
    id != "" && status == "" && /^Status:/ { status = $2 }
    END { flush() }' "$TODO_FILE"
}
has_item() {  # has_item <id>
  items | awk -F '\t' -v i="$1" '$1 == i { found = 1 } END { exit !found }'
}
rewrite() {  # rewrite <awk program> [awk -v args...]: edit the file in place, CR and trailing blank lines dropped
  program=$1; shift
  awk "$@" "{ sub(/\\r\$/, \"\") } $program" "$TODO_FILE" |
    awk 'NF { while (blanks > 0) { print ""; blanks-- } print; next } { blanks++ }' > "$TODO_FILE.tmp" &&
    mv "$TODO_FILE.tmp" "$TODO_FILE"
}

add_item() {  # add_item <category> <title...>
  category=$1; shift
  title=$(printf '%s' "$*" | tr -d '\r\n')
  case " $TODO_CATEGORIES " in
    *" $category "*) ;;
    *) stop "\"$category\" is not a category; use one of: $TODO_CATEGORIES (TODO_CATEGORIES in .agents/agent-kit.conf)" 2 ;;
  esac
  [ -n "$title" ] || stop "give a title: sh .agents/kit/todo.sh add <category> <title>" 2
  if [ ! -f "$TODO_FILE" ]; then
    [ -f "$KIT_DIR/todo.agentk.md" ] || stop "$KIT_DIR/todo.agentk.md is missing; run agent_dev_kit/install.sh"
    cp "$KIT_DIR/todo.agentk.md" "$TODO_FILE" || exit 1
  fi
  recorded=$(tr -d '\r' < "$TODO_FILE" | awk '/^Next ID:/ { print $3 + 0; exit }')
  highest=$(items | awk -F '\t' '{ n = substr($1, 3) + 0; if (n > max) max = n } END { print max + 0 }')
  number=$recorded
  [ -n "$number" ] && [ "$number" -gt "$highest" ] || number=$((highest + 1))
  id=$(printf 'T-%03d' "$number")
  had_line=0; [ -n "$recorded" ] && had_line=1
  # Without a "Next ID:" line (edited by hand), one goes under the title.
  rewrite '/^Next ID:/ && !done { print "Next ID: " n + 1; done = 1; next }
    !had && !done && /^# / { print; print ""; print "Next ID: " n + 1; done = 1; next }
    { print }' -v n="$number" -v had="$had_line"
  printf '\n## %s: %s\n\nCategory: %s\nStatus: open\nAdded: %s\nFrom:\nRefs:\n' \
    "$id" "$title" "$category" "$(date +%Y-%m-%d)" >> "$TODO_FILE"
  echo "$id"
}

set_status() {  # set_status <id> <open|doing>
  case "$2" in open|doing) ;; *) stop "status is open or doing (done: sh .agents/kit/todo.sh done $1)" 2 ;; esac
  has_item "$1" || stop "no item $1 in $TODO_FILE; see them with: sh .agents/kit/todo.sh list"
  rewrite '/^## / { inside = (index($0, "## " id ":") == 1) }
    inside && !done && /^Status:/ { print "Status: " status; done = 1; next }
    { print }' -v id="$1" -v status="$2"
  echo "todo: $1 is $2"
}

remove_item() {  # remove_item <id>
  has_item "$1" || stop "no item $1 in $TODO_FILE; see them with: sh .agents/kit/todo.sh list"
  title=$(items | awk -F '\t' -v i="$1" '$1 == i { print $4 }')
  rewrite '/^## / { inside = (index($0, "## " id ":") == 1) } !inside { print }' -v id="$1"
  echo "todo: removed $1: $title"
}

show_item() {  # show_item <id>
  has_item "$1" || stop "no item $1 in $TODO_FILE; see them with: sh .agents/kit/todo.sh list"
  awk -v id="$1" '{ sub(/\r$/, "") } /^## / { inside = (index($0, "## " id ":") == 1) } inside { print }' "$TODO_FILE"
}

list_refs() {  # every path in backticks on a Refs line: id, path
  [ -f "$TODO_FILE" ] || return 0
  awk 'BEGIN { OFS = "\t" } { sub(/\r$/, "") }
    /^## / { id = ""; if ($0 ~ /^## T-[0-9]+:/) { id = $2; sub(/:$/, "", id) } next }
    id != "" && /^Refs:/ { n = split($0, parts, "`"); for (i = 2; i < n; i += 2) if (parts[i] != "") print id, parts[i] }' "$TODO_FILE"
}

summary() {  # "5 todo(s) in TODO.agentk.md (2 experiment, 1 bug); doing: T-003"
  items | awk -F '\t' -v file="$TODO_FILE" '
    { total++; if (!($2 in seen)) order[++kinds] = $2; seen[$2]++
      if ($3 == "doing") doing = doing (doing == "" ? "" : ", ") $1 }
    END {
      if (!total) exit
      for (i = 1; i <= kinds; i++) parts = parts (i > 1 ? ", " : "") seen[order[i]] " " order[i]
      printf "%d todo(s) in %s (%s)", total, file, parts
      if (doing != "") printf "; doing: %s", doing
      print "" }'
}

case "${1:-}" in
  add) shift; [ $# -ge 1 ] || stop "usage: todo.sh add <category> <title>" 2; add_item "$@" ;;
  list)
    filter=${2:-}
    items | awk -F '\t' -v f="$filter" 'f == "" || $2 == f || $3 == f' ;;
  show) id=$(item_id "${2:-}") || { echo "$id"; exit 2; }; show_item "$id" ;;
  set) id=$(item_id "${2:-}") || { echo "$id"; exit 2; }; set_status "$id" "${3:-}" ;;
  done) id=$(item_id "${2:-}") || { echo "$id"; exit 2; }; remove_item "$id" ;;
  refs) list_refs ;;
  count) summary ;;
  *) echo "usage: todo.sh add <category> <title> | list [category|open|doing] | show <id> | set <id> <open|doing> | done <id> | refs | count"; exit 2 ;;
esac
