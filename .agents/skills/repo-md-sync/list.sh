#!/bin/sh
# The repo's own Markdown files (the ones people wrote), and how much code
# changed since each was last updated. Read only; the repo-md-sync skill
# starts from it.
#
# Usage (from anywhere in the repo):
#   sh .agents/skills/repo-md-sync/list.sh
#
# Prints one line per file: <file> TAB <last updated> TAB <changed> TAB <scope>
#   last updated  the date of the last commit that changed the file, or
#                 "uncommitted" for a new file
#   changed       how many other files (not Markdown) changed in the scope
#                 since then; 0 means the file is probably still true
#   scope         the paths in its <!-- agent-kit: source_paths ... --> line
#                 (from the file's folder), else its folder ("." for the root)
# Left out: kit docs (names ending in DOC_SUFFIX), the agent files (AGENTS.md,
# CLAUDE.md, GEMINI.md, SKILL.md and the local wiring files), and the folders
# .agents/, .claude/, LEARNING_DIR and SKIP_DIRS.
cd "$(git rev-parse --show-toplevel)" || exit 1
SKIP_DIRS="node_modules .venv venv vendor target build dist out bin obj"
LEARNING_DIR="learning_docs"
DOC_SUFFIX=".agentk.md"
POINTER_FILES="CLAUDE.md"
[ -f .agents/kit/lib.sh ] && . ./.agents/kit/lib.sh && load_conf
TAB=$(printf '\t')

skipped() {  # skipped <path>: true when the file is not the people's own Markdown
  case "/$1" in
    */.agents/*|*/.claude/*|*/.agent-workspace/*|*/.github/copilot-instructions.md) return 0 ;;
  esac
  [ -n "$LEARNING_DIR" ] && case "$1" in "$LEARNING_DIR"/*) return 0 ;; esac
  for skip in $SKIP_DIRS; do
    case "/$1" in */"$skip"/*) return 0 ;; esac
  done
  [ -n "$DOC_SUFFIX" ] && case "$1" in *"$DOC_SUFFIX") return 0 ;; esac
  case " AGENTS.md AGENTS.override.md CLAUDE.md CLAUDE.local.md GEMINI.md SKILL.md $POINTER_FILES " in
    *" ${1##*/} "*) return 0 ;;
  esac
  return 1
}
scope_of() {  # scope_of <file>: the paths whose changes it describes
  folder=$(dirname "$1")
  anchors=$(tr -d '\r' < "$1" | sed -n 's/.*<!-- agent-kit: source_paths \(.*\) -->.*/\1/p' | head -1)
  [ -n "$anchors" ] || { echo "$folder"; return; }
  for path in $anchors; do
    if [ "$folder" = . ]; then printf '%s ' "$path"; else printf '%s ' "$folder/$path"; fi
  done
}
changed_since() {  # changed_since <commit> <path>...: files changed there since, not Markdown
  base=$1; shift
  { git -c core.quotepath=off diff --name-only "$base" -- "$@"
    git -c core.quotepath=off ls-files --others --exclude-standard -- "$@"
  } | grep -v -i '\.mdx\{0,1\}$' | LC_ALL=C sort -u | grep -c .
}

[ -z "$DOC_SUFFIX" ] &&
  echo "repo-md-sync: DOC_SUFFIX is empty, so kit docs have plain names here. Ask before you treat a file as the people's own." >&2

git -c core.quotepath=off ls-files --cached --others --exclude-standard -- '*.md' '*.mdx' | LC_ALL=C sort -u |
while IFS= read -r file; do
  [ -f "$file" ] || continue
  skipped "$file" && continue
  scope=$(scope_of "$file")
  base=$(git log -1 --format=%H -- "$file")
  if [ -z "$base" ]; then
    printf '%s\tuncommitted\t-\t%s\n' "$file" "$scope"
    continue
  fi
  date=$(git log -1 --format=%cs "$base")
  # shellcheck disable=SC2086  # scope is a path list
  printf '%s\t%s\t%s\t%s\n' "$file" "$date" "$(changed_since "$base" $scope)" "$scope"
done
