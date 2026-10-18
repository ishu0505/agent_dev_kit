#!/bin/sh
# End-to-end tests: install the kit into throwaway repos, then check that
# check.sh passes on a correct repo and names the fix for each known gap,
# that upgrades keep repo-owned files, and that both hooks block.
#
# Usage: sh tests/run.sh   (needs sh, git, Python 3; no network)
# Runs on macOS, Linux and Windows (Git Bash); CI runs all three.

set -u
KIT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PASSED=0
FAILED=0

ok() { PASSED=$((PASSED + 1)); echo "ok   $1"; }
bad() { FAILED=$((FAILED + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/     /'; }
git_quiet() { git -c user.name=test -c user.email=test@example.com "$@" >/dev/null 2>&1; }
native() {  # native <path>: the path as the OS writes it (C:/... on Windows)
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}
edit() {  # edit <sed expression> <file>: in-place edit on BSD and GNU sed
  sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"
}

expect_pass() {  # expect_pass <name> <repo>
  out=$(cd "$2" && sh .agents/kit/check.sh 2>&1) && ok "$1" || bad "$1" "$out"
}
expect_fail() {  # expect_fail <name> <repo> <text the failure must contain>
  out=$(cd "$2" && sh .agents/kit/check.sh 2>&1)
  if [ $? -ne 0 ] && printf '%s' "$out" | grep -qF "$3"; then ok "$1"; else bad "$1" "$out"; fi
}

new_repo() {  # new_repo <name>: an empty git repo with the kit installed
  mkdir "$WORK/$1" && git -C "$WORK/$1" init -q
  sh "$KIT/install.sh" "$WORK/$1" > "$WORK/$1.install.log" 2>&1
}

write_map() {  # write_map <folder> <one-line purpose>: AGENTS.md + README + CLAUDE.md
  printf '# %s\n\n%s\n\n## Further reading\n\n- `README.md` — details\n' "$(basename "$1")" "$2" > "$1/AGENTS.md"
  printf '# %s\n\n%s\n' "$(basename "$1")" "$2" > "$1/README.md"
  echo "@AGENTS.md" > "$1/CLAUDE.md"
}

# --- Empty repo -------------------------------------------------------------
new_repo empty
R="$WORK/empty"
expect_fail "empty repo: install alone asks for the root map" "$R" "AGENTS.md is missing"
# A link on macOS and Linux; a copy where symlinks fail (Windows).
grep -qE "linked .claude/skills|copied .agents/skills -> .claude/skills" "$WORK/empty.install.log" &&
  ok "install creates .claude/skills" || bad "install creates .claude/skills" "$(cat "$WORK/empty.install.log")"
printf '# empty\n\nA new project.\n\n| Path | What | Read first |\n|---|---|---|\n| `DECISIONS.md` | Lineage | |\n' > "$R/AGENTS.md"
echo "@AGENTS.md" > "$R/CLAUDE.md"
cp "$KIT/templates/docs/DECISIONS.md" "$R/DECISIONS.md"
git_quiet -C "$R" add -A
expect_pass "empty repo: root map + decisions pass" "$R"

# --- Go repo ----------------------------------------------------------------
new_repo go
R="$WORK/go"
mkdir -p "$R/cmd/api" "$R/internal/store"
printf 'module example.com/shop\n\ngo 1.22\n' > "$R/go.mod"
printf 'package main\n\nfunc main() {}\n' > "$R/cmd/api/main.go"
printf 'package store\n' > "$R/internal/store/store.go"
edit 's/^UNIT_PARENTS=""/UNIT_PARENTS="cmd internal"/' "$R/.agents/agent-kit.conf"
printf '# shop\n\nA shop API.\n\n## Where things are\n\n| Path | What | Read first |\n|---|---|---|\n| `cmd/api/` | HTTP server | `cmd/api/AGENTS.md` |\n| `internal/store/` | Storage | `internal/store/AGENTS.md` |\n| `go.mod` | Module | |\n' > "$R/AGENTS.md"
echo "@AGENTS.md" > "$R/CLAUDE.md"
write_map "$R/cmd/api" "The HTTP server."
write_map "$R/internal/store" "Storage."
git_quiet -C "$R" add -A
git_quiet -C "$R" commit -m init
expect_pass "go repo: correct setup passes" "$R"

variant() {  # variant <name>: a copy of the passing Go repo to break
  cp -R "$WORK/go" "$WORK/$1"
  echo "$WORK/$1"
}

V=$(variant dead); printf '| `nope/` | gone | |\n' >> "$V/AGENTS.md"
expect_fail "dead path in a map" "$V" "names a missing path: nope"

V=$(variant long); i=0; while [ $i -lt 41 ]; do echo "line" >> "$V/cmd/api/AGENTS.md"; i=$((i + 1)); done
expect_fail "unit map over its limit" "$V" "(max 40)"

V=$(variant nomap); rm "$V/internal/store/AGENTS.md"
expect_fail "unit without a map" "$V" "internal/store has no AGENTS.md"

V=$(variant pointer); rm "$V/cmd/api/CLAUDE.md"
expect_fail "map without its CLAUDE.md pointer" "$V" "cmd/api/CLAUDE.md does not import"

V=$(variant newunit); mkdir "$V/internal/cache"; echo "package cache" > "$V/internal/cache/cache.go"
expect_fail "new unit folder is noticed" "$V" "internal/cache has no README.md"

V=$(variant skillfile); mkdir -p "$V/.agents/skills/extra"; echo "x" > "$V/.agents/skills/extra/SKILL.md"
expect_fail "untracked skill" "$V" "not in git"

V=$(variant copies); rm -rf "$V/.claude/skills"; cp -R "$V/.agents/skills" "$V/.claude/skills"
echo "drift" >> "$V/.claude/skills/lineage/SKILL.md"
expect_fail "drifted skill copy" "$V" ".claude/skills is"

V=$(variant homepath); edit 's#sh -c#sh /home/someone/hook.sh; sh -c#' "$V/.claude/settings.json"
expect_fail "hook with a home-folder path" "$V" "hard-codes a path"

V=$(variant winpath); edit 's#sh -c#sh C:\\\\Users\\\\someone\\\\hook.sh; sh -c#' "$V/.codex/hooks.json"
expect_fail "hook with a Windows home path" "$V" "hard-codes a path"

V=$(variant missingscript); edit "s#stop-hook.sh#gone.sh#" "$V/.codex/hooks.json"
expect_fail "hook running a missing script" "$V" "gone.sh, which does not exist"

V=$(variant hooksoff); git -C "$V" config --unset core.hooksPath
expect_fail "pre-commit not active" "$V" "pre-commit check is not active"

# --- Windows, macOS and Linux ----------------------------------------------
V=$(variant copymode); edit 's/^SKILLS_LINK=.*/SKILLS_LINK="copy"/' "$V/.agents/agent-kit.conf"
(cd "$V" && sh .agents/kit/sync-skills.sh >/dev/null); git_quiet -C "$V" add -A
expect_pass "copy mode: synced copy passes" "$V"
echo "new step" >> "$V/.agents/skills/scaffold/SKILL.md"
expect_fail "copy mode: edited skill not synced" "$V" "out of sync"
(cd "$V" && sh .agents/kit/sync-skills.sh >/dev/null); git_quiet -C "$V" add -A
expect_pass "copy mode: sync-skills.sh repairs it" "$V"

mkdir -p "$WORK/nolinks"; printf '#!/bin/sh\nexit 1\n' > "$WORK/nolinks/ln"; chmod +x "$WORK/nolinks/ln"
V=$(variant autocopy); rm -rf "$V/.claude/skills"
(cd "$V" && PATH="$WORK/nolinks:$PATH" sh .agents/kit/sync-skills.sh >/dev/null); git_quiet -C "$V" add -A
grep -q '^SKILLS_LINK="copy"' "$V/.agents/agent-kit.conf" && ok "no symlinks: sync switches to copy mode" || bad "no symlinks: sync switches to copy mode"
expect_pass "no symlinks: copy mode passes" "$V"

V=$(variant plainfile); rm -rf "$V/.claude/skills"; printf '../.agents/skills' > "$V/.claude/skills"
expect_fail "symlink checked out as a plain file" "$V" "cannot use symlinks"

V=$(variant crlfrule); git_quiet -C "$V" rm -q --cached .gitattributes; rm "$V/.gitattributes"
expect_fail "missing LF rule for scripts" "$V" "line endings"

V=$(variant execbit); git -C "$V" update-index --chmod=-x .githooks/pre-commit
expect_fail "hook not executable in git" "$V" "not executable in git"

V=$(variant crlfmap); awk '{ printf "%s\r\n", $0 }' "$V/AGENTS.md" > "$V/AGENTS.tmp" && mv "$V/AGENTS.tmp" "$V/AGENTS.md"
expect_pass "map with Windows line endings passes" "$V"
printf '| `nope/` | gone | |\r\n' >> "$V/AGENTS.md"
expect_fail "map with Windows line endings: dead path found" "$V" "missing path: nope"

H="$WORK/home"; mkdir -p "$H"
HOME="$H" sh "$KIT/install-global.sh" >/dev/null
[ -f "$H/.claude/skills/agent-kit/SKILL.md" ] && [ -f "$H/.agents/skills/agent-kit/SKILL.md" ] &&
  [ -f "$H/.gemini/config/skills/agent-kit/SKILL.md" ] && [ -f "$H/.gemini/antigravity/skills/agent-kit/SKILL.md" ] && ok "global skill installed for every agent" || bad "global skill installed for every agent"
H2="$WORK/home2"; mkdir -p "$H2"
HOME="$H2" PATH="$WORK/nolinks:$PATH" sh "$KIT/install-global.sh" >/dev/null
[ "$(cat "$H2/.agents/skills/agent-kit/kit-path" 2>/dev/null)" = "$KIT" ] && ok "no symlinks: global skill copied with kit-path" || bad "no symlinks: global skill copied with kit-path"
HOME="$H2" sh "$KIT/install-global.sh" --remove >/dev/null
[ ! -e "$H2/.claude/skills/agent-kit" ] && ok "global skill removed" || bad "global skill removed"

V=$(variant learning); mkdir "$V/learning_docs"; echo "x" > "$V/learning_docs/00-overview.md"
expect_pass "learning docs on disk but ignored" "$V"
git_quiet -C "$V" add -f learning_docs/00-overview.md
expect_fail "learning doc staged" "$V" "learning docs are tracked"

V=$(variant ledger); mkdir -p "$V/experiments/latency"; echo x > "$V/experiments/latency/run.sh"
cp "$KIT/templates/docs/EXPERIMENTS.md" "$V/experiments/EXPERIMENTS.md"
edit 's#^LEDGER=""#LEDGER="experiments/EXPERIMENTS.md"#' "$V/.agents/agent-kit.conf"
expect_fail "experiment without a ledger row" "$V" "latency has no row"
echo '| `latency/` | Is it fast? | 1 run |  | none | none yet |' >> "$V/experiments/EXPERIMENTS.md"
expect_fail "ledger row without an outcome" "$V" "latency has no outcome"
edit 's#| 1 run |  |#| 1 run | pending: not run yet |#' "$V/experiments/EXPERIMENTS.md"
expect_pass "ledger row with pending outcome" "$V"

# --- Upgrade keeps repo-owned files ----------------------------------------
V=$(variant upgrade)
echo "# note" >> "$V/.agents/agent-kit.conf"
echo "tampered" >> "$V/.agents/kit/check.sh"
before=$(cat "$V/.agents/agent-kit.conf" "$V/AGENTS.md" "$V/.claude/settings.json" | cksum)
sh "$KIT/install.sh" "$V" > /dev/null 2>&1
after=$(cat "$V/.agents/agent-kit.conf" "$V/AGENTS.md" "$V/.claude/settings.json" | cksum)
[ "$before" = "$after" ] && ok "upgrade keeps config, maps and settings" || bad "upgrade keeps config, maps and settings"
[ "$(cksum < "$V/.agents/kit/check.sh")" = "$(cksum < "$KIT/templates/kit/check.sh")" ] && ok "upgrade replaces kit-owned check.sh" || bad "upgrade replaces kit-owned check.sh"

# --- Pre-commit blocks ------------------------------------------------------
V=$(variant commit); printf '| `nope/` | gone | |\n' >> "$V/AGENTS.md"; git_quiet -C "$V" add -A
if git_quiet -C "$V" commit -m broken; then bad "pre-commit blocks a broken map"; else ok "pre-commit blocks a broken map"; fi
git -C "$V" checkout -q HEAD -- AGENTS.md
if git_quiet -C "$V" commit --allow-empty -m fine; then ok "pre-commit allows a clean repo"; else bad "pre-commit allows a clean repo"; fi

# --- Stop hook --------------------------------------------------------------
transcript() {  # transcript <file> <tool name> <file_path>
  printf '%s\n' '{"type":"user","message":{"content":"go"}}' \
    "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"$2\",\"input\":{\"command\":\"x\",\"file_path\":\"$(native "$3")\"}}]}}" > "$1"
}
hook() {  # hook <repo> <transcript>: the hook's output
  echo "{\"transcript_path\":\"$(native "$2")\",\"cwd\":\"$(native "$1/cmd")\"}" | (cd "$1" && sh .agents/kit/stop-hook.sh)
}
V=$(variant hookfail); printf '| `nope/` | gone | |\n' >> "$V/AGENTS.md"
transcript "$WORK/t1.jsonl" Bash "" ; edit 's#"file_path":"[^"]*"#"file_path":""#' "$WORK/t1.jsonl"
hook "$V" "$WORK/t1.jsonl" | grep -q '"block"' && ok "stop hook blocks after a shell edit that broke a map" || bad "stop hook blocks after a shell edit that broke a map"
out=$(hook "$WORK/go" "$WORK/t1.jsonl")
[ -z "$out" ] && ok "stop hook passes a clean repo" || bad "stop hook passes a clean repo" "$out"
transcript "$WORK/t2.jsonl" Edit "$WORK/go/cmd/api/main.go"
hook "$WORK/go" "$WORK/t2.jsonl" | grep -q 'Docs step' && ok "stop hook asks for the docs step after a code edit" || bad "stop hook asks for the docs step after a code edit"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
