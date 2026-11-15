#!/bin/sh
# PreToolUse guard for team repos (MAPS="beside"): refuse a tool call that
# would change one of the team's agent files (TEAM_FILES in lib.sh, tracked
# by git), before it runs. The Stop hook only warns after the change.
#
# Usage: sh .agents/kit/pre-edit.sh <claude|codex|agy>   (hook JSON on stdin)
#
# It looks at:
#   file edits     file_path, notebook_path (Claude), TargetFile (Antigravity),
#                  "*** Add/Update/Delete File: <path>" lines (Codex apply_patch)
#   shell commands a redirect (> or >>) into a team file; tee, rm, mv,
#                  truncate, git rm, git mv, sed -i or perl -i on one; or
#                  cp/ln/install onto one
# Reads such as `cat AGENTS.md` pass. On a match it prints the agent's deny
# JSON; otherwise nothing. It never fails: any error exits 0 silently.
# Installed by agent_dev_kit; do not edit here.
AGENT=${1:-claude}
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0
MAPS=own
DOC_SUFFIX=".agentk.md"
. ./.agents/kit/lib.sh 2>/dev/null && load_conf
[ "$MAPS" = beside ] || exit 0
RAW=$(cat)
[ -n "$RAW" ] || exit 0

unescape() {  # stdin: JSON string escapes that matter for paths and commands
  sed 's#\\\\#/#g; s/\\n/\
/g; s/\\t/ /g; s/\\"/"/g'
}

json_values() {  # json_values <key>...: each "key": "string" (or ["strings"]) in the input
  for _key in "$@"; do
    printf '%s\n' "$RAW" |
      sed -n "s/.*\"$_key\"[[:space:]]*:[[:space:]]*\"\([^\"\\]*\(\\\\.[^\"\\]*\)*\)\".*/\1/p" | unescape
    printf '%s\n' "$RAW" |
      sed -n "s/.*\"$_key\"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p" |
      sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//; s/"[[:space:]]*,[[:space:]]*"/\
/g' | unescape  # an argv array: one element per line
  done
}

edit_paths() {  # the files a file-edit tool would write
  json_values file_path notebook_path TargetFile
  json_values command input patch | sed -n 's/^.*\*\*\* [A-Za-z]* File: \(.*\)$/\1/p' |
    sed 's/[[:space:]]*$//'
}

shell_write_targets() {  # team-file names a shell command would write
  json_values command CommandLine cmd | awk -v names="$TEAM_FILES" '
    BEGIN { n = split(names, team, " ") }
    function is_team(word,   i, base) {
      gsub(/^["'\''(]+|["'\'');)]+$/, "", word); base = word; sub(/.*\//, "", base)
      for (i = 1; i <= n; i++) if (base == team[i]) return word
      return ""
    }
    { line = $0
      while (match(line, />>?[[:space:]]*[^[:space:];|&]+/)) {
        target = substr(line, RSTART, RLENGTH); sub(/^>>?[[:space:]]*/, "", target)
        if ((hit = is_team(target)) != "") print hit
        line = substr(line, RSTART + RLENGTH)
      }
      count = split($0, parts, /(\|\||&&|[;|&])/)
      for (p = 1; p <= count; p++) {
        words = split(parts[p], w, /[[:space:]]+/); first = 1
        while (first <= words && w[first] == "") first++
        while (words > first && w[words] == "") words--
        cmd = w[first]; sub(/.*\//, "", cmd)
        inplace = 0
        for (k = first + 1; k <= words; k++) if (w[k] ~ /^-i/ || w[k] == "--in-place") inplace = 1
        for (k = first + 1; k <= words; k++) {
          if ((hit = is_team(w[k])) == "") continue
          if (cmd == "tee" || cmd == "rm" || cmd == "mv" || cmd == "truncate" || cmd == "unlink") print hit
          else if ((cmd == "sed" || cmd == "perl") && inplace) print hit
          else if ((cmd == "cp" || cmd == "ln" || cmd == "install") && k == words) print hit
          else if (cmd == "git" && (w[first + 1] == "rm" || w[first + 1] == "mv")) print hit
        }
      }
    }'
}

relative_path() {  # relative_path <path>: the path from the repo root
  case "$1" in
    "$ROOT"/*) printf '%s\n' "${1#"$ROOT"/}" ;;
    /*|[A-Za-z]:/*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "${CWD_REL:+$CWD_REL/}$1" ;;
  esac
}

is_team_file() {  # is_team_file <repo-relative path>: a team agent file git tracks
  _name=${1##*/}
  case " $TEAM_FILES " in *" $_name "*) ;; *) return 1 ;; esac
  git ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

print_deny() {  # print_deny <path>: the agent's refusal, in its own JSON shape
  _file=$(printf '%s' "$1" | sed 's/[\\"]/\\&/g')
  _reason="$_file belongs to the team (this repo works beside them); agent-kit never edits it. Put the change in AGENTS$DOC_SUFFIX instead. If the team file itself must change, the user edits it by hand."
  if [ "$AGENT" = agy ]; then
    printf '{"decision": "deny", "reason": "%s"}\n' "$_reason"
  else
    printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "%s"}}\n' "$_reason"
  fi
}

CWD=$(json_values cwd | head -1)
CWD_REL=""
case "$CWD" in "$ROOT"/*) CWD_REL=${CWD#"$ROOT"/} ;; esac
{ edit_paths; shell_write_targets; } | while IFS= read -r target; do
  [ -n "$target" ] || continue
  path=$(relative_path "$target")
  is_team_file "$path" || continue
  print_deny "$path"
  break
done
exit 0
