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
# Every unit gets a map here, whatever its size (thresholds are tested below).
edit 's/^MAP_MIN_FILES=.*/MAP_MIN_FILES=""/; s/^MAP_MIN_LINES=.*/MAP_MIN_LINES=""/' "$R/.agents/agent-kit.conf"
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

# --- Share modes --------------------------------------------------------------
mode_repo() {  # mode_repo <mode>: a new repo in that share mode, maps written, all staged
  R="$WORK/mode-$1"
  mkdir "$R" && git -C "$R" init -q
  sh "$KIT/install.sh" --share "$1" "$R" > "$WORK/mode-$1.log" 2>&1
  printf '# m\n\nA repo.\n' > "$R/AGENTS.md"; echo "@AGENTS.md" > "$R/CLAUDE.md"
  cp "$KIT/templates/docs/DECISIONS.md" "$R/DECISIONS.md"
  mkdir -p "$R/learning_docs"; echo "# Overview" > "$R/learning_docs/00-overview.md"
  echo "package main" > "$R/main.go"
  git_quiet -C "$R" add -A
}
staged() { git -C "$1" diff --cached --name-only; }  # staged <repo>
has() { staged "$1" | grep -qx "$2"; }               # has <repo> <path>

mode_repo agent; R="$WORK/mode-agent"
expect_pass "share agent: checks pass" "$R"
has "$R" AGENTS.md && has "$R" .agents/kit/check.sh && ! has "$R" learning_docs/00-overview.md &&
  ok "share agent: agent files staged, learning docs not" || bad "share agent: agent files staged, learning docs not" "$(staged "$R")"

mode_repo all; R="$WORK/mode-all"
expect_pass "share all: checks pass" "$R"
has "$R" AGENTS.md && has "$R" learning_docs/00-overview.md &&
  ok "share all: agent files and learning docs staged" || bad "share all: agent files and learning docs staged" "$(staged "$R")"

mode_repo learning; R="$WORK/mode-learning"
expect_pass "share learning: checks pass" "$R"
has "$R" learning_docs/00-overview.md && has "$R" main.go && [ -z "$(staged "$R" | grep -E '^(AGENTS|CLAUDE|DECISIONS)\.md$|^\.(agents|claude|codex|githooks)/|^\.git(ignore|attributes)$')" ] &&
  ok "share learning: learning docs staged, no agent file or kit rule" || bad "share learning: learning docs staged, no agent file or kit rule" "$(staged "$R")"
git_quiet -C "$R" commit -m first && ok "share learning: pre-commit runs from local files" || bad "share learning: pre-commit runs from local files"

mode_repo none; R="$WORK/mode-none"
expect_pass "share none: checks pass" "$R"
[ "$(staged "$R")" = "main.go" ] && ok "share none: only code is staged" || bad "share none: only code is staged" "$(staged "$R")"
git_quiet -C "$R" add -f AGENTS.md
expect_fail "share none: a force-added map is caught" "$R" "keeps agent files local"
if git_quiet -C "$R" commit -m leak; then bad "share none: pre-commit blocks the leak"; else ok "share none: pre-commit blocks the leak"; fi

V=$(variant teamswitch); git -C "$V" config user.email me@example.com  # someone else committed the maps
sh "$KIT/install.sh" --share none "$V" > "$WORK/teamswitch.log" 2>&1
grep -q "WARNING: other people committed" "$WORK/teamswitch.log" && ! grep -q "run  git rm -r --cached" "$WORK/teamswitch.log" &&
  ok "switch to none: warns before untracking teammates' files" || bad "switch to none: warns before untracking teammates' files" "$(cat "$WORK/teamswitch.log")"
sh "$KIT/install.sh" --share none --confirm-untrack "$V" > "$WORK/teamswitch2.log" 2>&1
grep -q "run  git rm -r --cached" "$WORK/teamswitch2.log" && ok "switch to none: --confirm-untrack prints the command" || bad "switch to none: --confirm-untrack prints the command" "$(cat "$WORK/teamswitch2.log")"

V=$(variant switch)   # the committed Go repo (share agent) moves to share none
git -C "$V" config user.email test@example.com  # the only author
sh "$KIT/install.sh" --share none "$V" > "$WORK/switch.log" 2>&1
grep -q "git rm -r --cached" "$WORK/switch.log" && ok "switch to none: install says how to untrack" || bad "switch to none: install says how to untrack" "$(cat "$WORK/switch.log")"
expect_fail "switch to none: tracked agent files are caught" "$V" "keeps agent files local"
(cd "$V" && set -f && git rm -r --cached -q --ignore-unmatch -- AGENTS.md ':(glob)**/AGENTS.md' CLAUDE.md ':(glob)**/CLAUDE.md' DECISIONS.md PLAN.md .agents .claude .codex .githooks .gitattributes 2>/dev/null; true)
expect_pass "switch to none: passes once untracked" "$V"

# --- Skills the repo edited or owns are never lost ---------------------------
KIT2="$WORK/kit2"; cp -R "$KIT" "$KIT2"; echo "- a step added in a newer kit" >> "$KIT2/templates/skills/scaffold/SKILL.md"
skill_is() { grep -q "$2" "$1/.agents/skills/scaffold/SKILL.md"; }  # skill_is <repo> <text>
incoming() { echo "$(git -C "$1" rev-parse --absolute-git-dir)/agent-kit/incoming/scaffold"; }

V=$(variant untouched); sh "$KIT2/install.sh" "$V" > /dev/null 2>&1
skill_is "$V" "a step added in a newer kit" && ok "unedited kit skill takes the new version" || bad "unedited kit skill takes the new version"

V=$(variant edited); echo "- our own step" >> "$V/.agents/skills/scaffold/SKILL.md"
sh "$KIT/install.sh" "$V" > "$WORK/edited.log" 2>&1
skill_is "$V" "our own step" && [ ! -d "$(incoming "$V")" ] && ok "edited skill kept when the kit has no newer version" || bad "edited skill kept when the kit has no newer version" "$(cat "$WORK/edited.log")"
sh "$KIT2/install.sh" "$V" > "$WORK/edited2.log" 2>&1
skill_is "$V" "our own step" && ! skill_is "$V" "a step added in a newer kit" && grep -q "a step added in a newer kit" "$(incoming "$V")/SKILL.md" &&
  grep -q "Merge the new kit version" "$WORK/edited2.log" && ok "edited skill kept; newer kit version waits in incoming" || bad "edited skill kept; newer kit version waits in incoming" "$(cat "$WORK/edited2.log")"
[ ! -e "$V/.agents/skills/scaffold.kit-new" ] && [ -z "$(ls "$V/.agents/skills" | grep -v -E '^(docs-sync|learning-docs|lineage|scaffold|catch-up|wrap-up|explain-diff)$')" ] &&
  ok "incoming versions stay out of the skills folder" || bad "incoming versions stay out of the skills folder" "$(ls "$V/.agents/skills")"
git_quiet -C "$V" add -A
expect_pass "checks pass while an update waits in incoming" "$V"
sh "$KIT2/install.sh" "$V" > "$WORK/edited3.log" 2>&1
! grep -q "Merge the new kit version" "$WORK/edited3.log" && skill_is "$V" "our own step" && ok "the same update is offered only once" || bad "the same update is offered only once" "$(cat "$WORK/edited3.log")"

V=$(variant owned); echo "- our own step" >> "$V/.agents/skills/scaffold/SKILL.md"
edit 's/^OWN_SKILLS=.*/OWN_SKILLS="scaffold"/' "$V/.agents/agent-kit.conf"
sh "$KIT2/install.sh" "$V" > "$WORK/owned.log" 2>&1
skill_is "$V" "our own step" && [ ! -d "$(incoming "$V")" ] && grep -q "in OWN_SKILLS" "$WORK/owned.log" &&
  ok "OWN_SKILLS: never touched, no update offered" || bad "OWN_SKILLS: never touched, no update offered" "$(cat "$WORK/owned.log")"

mkdir "$WORK/ownskill" && git -C "$WORK/ownskill" init -q
mkdir -p "$WORK/ownskill/.agents/skills/lineage" "$WORK/ownskill/.agents/skills/deploy"
printf -- '---\nname: lineage\n---\nOur lineage.\n' > "$WORK/ownskill/.agents/skills/lineage/SKILL.md"
printf -- '---\nname: deploy\n---\nDeploy.\n' > "$WORK/ownskill/.agents/skills/deploy/SKILL.md"
sh "$KIT/install.sh" "$WORK/ownskill" > "$WORK/ownskill.log" 2>&1
grep -q "Our lineage." "$WORK/ownskill/.agents/skills/lineage/SKILL.md" && grep -q "is not the kit's version" "$WORK/ownskill.log" &&
  grep -q "Deploy." "$WORK/ownskill/.agents/skills/deploy/SKILL.md" &&
  ok "repo's own skills survive setup, same name or not" || bad "repo's own skills survive setup, same name or not" "$(cat "$WORK/ownskill.log")"

# --- House-cleaning inventory -------------------------------------------------
R="$WORK/ownskill"
printf '# Notes\n' > "$R/NOTES.md"; printf 'rule\n' > "$R/.cursorrules"; printf '# x\n' > "$R/AGENTS.md"
edit 's/^OWN_SKILLS=.*/OWN_SKILLS="lineage"/' "$R/.agents/agent-kit.conf"
before=$(git -C "$R" status --porcelain | cksum)
out=$(sh "$KIT/templates/kit/inventory.sh" "$R")
after=$(git -C "$R" status --porcelain | cksum)
printf '%s' "$out" | grep -q "^Maps and pointer files" && printf '%s' "$out" | grep -q "^Rules for other agents" &&
  printf '%s' "$out" | grep -q "lineage .*repo-owned (OWN_SKILLS)" && printf '%s' "$out" | grep -q "docs-sync .*same name as a kit skill" &&
  printf '%s' "$out" | grep -q "NOTES.md  \[untracked" && ok "inventory groups maps, rules, skills and stray docs" || bad "inventory groups maps, rules, skills and stray docs" "$out"
[ "$before" = "$after" ] && ok "inventory changes nothing" || bad "inventory changes nothing"

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

# --- Every map, prose paths, env vars, commands ----------------------------
V=$(variant nested); mkdir -p "$V/cmd/api/handlers"
printf '# handlers\n\n| Path | What |\n|---|---|\n| `gone.go` | x |\n' > "$V/cmd/api/handlers/AGENTS.md"
echo "@AGENTS.md" > "$V/cmd/api/handlers/CLAUDE.md"
expect_fail "a map below a unit is checked too" "$V" "names a missing path: gone.go"

V=$(variant prose); printf '\nThe store lives in `internal/store/config.go`.\n' >> "$V/AGENTS.md"
expect_fail "a dead path in prose is caught" "$V" "names a missing path: internal/store/config.go"
edit 's#^The store lives in .*#& <!-- agent-kit: skip -->#' "$V/AGENTS.md"
printf 'Not paths: `os.path`, `owner/repo`, `HTTP/1.1`, `--flag`, `learning_docs/`. A file named alone: `store.go`.\n' >> "$V/AGENTS.md"
expect_pass "skip marker and words that are not paths pass" "$V"

V=$(variant spaces); mkdir "$V/my docs"; echo x > "$V/my docs/notes.txt"
printf '| `my docs/` | Notes |\n' >> "$V/AGENTS.md"; git_quiet -C "$V" add -A
expect_pass "a mapped path with a space passes" "$V"

V=$(variant envvar); edit 's/^CHECK_ENV=.*/CHECK_ENV="yes"/' "$V/.agents/agent-kit.conf"
printf '\nSet `SHOP_DB_URL` to the database.\n' >> "$V/AGENTS.md"
expect_fail "an env var no code uses is caught" "$V" "SHOP_DB_URL"
printf 'package store\n\nconst env = "SHOP_DB_URL"\n' > "$V/internal/store/store.go"
expect_pass "an env var the code uses passes" "$V"

V=$(variant commands); edit 's#^RUN_COMMANDS_MAPS=.*#RUN_COMMANDS_MAPS="cmd/api/AGENTS.md"#' "$V/.agents/agent-kit.conf"
printf '\n## Run\n\n```bash\ntest -f main.go\nfalse\n```\n' >> "$V/cmd/api/AGENTS.md"
expect_pass "map commands run only with --run-commands" "$V"
out=$(cd "$V" && sh .agents/kit/check.sh --run-commands 2>&1)
printf '%s' "$out" | grep -q "## Run / ## Check in cmd/api/AGENTS.md fail" && ok "a failing map command is caught" || bad "a failing map command is caught" "$out"
edit 's/^false$/true/' "$V/cmd/api/AGENTS.md"
out=$(cd "$V" && sh .agents/kit/check.sh --run-commands 2>&1) && ok "working map commands pass" || bad "working map commands pass" "$out"

# --- Unit size thresholds ---------------------------------------------------
new_repo sizes; R="$WORK/sizes"
mkdir -p "$R/pkgs/small" "$R/pkgs/big"
echo "package small" > "$R/pkgs/small/a.go"
for f in a b c; do echo "package big" > "$R/pkgs/big/$f.go"; done
edit 's/^UNIT_PARENTS=""/UNIT_PARENTS="pkgs"/; s/^MAP_MIN_FILES=.*/MAP_MIN_FILES="3"/' "$R/.agents/agent-kit.conf"
printf '# sizes\n\n| Path | What | Read first |\n|---|---|---|\n| `pkgs/` | Packages | |\n' > "$R/AGENTS.md"
echo "@AGENTS.md" > "$R/CLAUDE.md"; git_quiet -C "$R" add -A
expect_fail "a unit past the threshold needs its map" "$R" "pkgs/big has no README.md"
out=$(cd "$R" && sh .agents/kit/check.sh 2>&1); printf '%s' "$out" | grep -q "pkgs/small" &&
  bad "a small unit needs only a row" "$out" || ok "a small unit needs only a row"
edit 's#^MAP_EXEMPT=.*#MAP_EXEMPT="pkgs/big"#' "$R/.agents/agent-kit.conf"
expect_pass "MAP_EXEMPT lets a big unit go without a map" "$R"
edit 's#^MAP_REQUIRED=.*#MAP_REQUIRED="pkgs/small"#' "$R/.agents/agent-kit.conf"
expect_fail "MAP_REQUIRED asks a small unit for its map" "$R" "pkgs/small has no AGENTS.md"
edit 's#^MAP_REQUIRED=.*#MAP_REQUIRED=""#' "$R/.agents/agent-kit.conf"
printf '# sizes\n\nNo rows.\n' > "$R/AGENTS.md"
expect_fail "a small unit no map names is caught" "$R" "no map names pkgs/small"

# --- Only what this change caused blocks ----------------------------------------
V=$(variant teammate); printf '| `nope/` | gone | |\n' >> "$V/AGENTS.md"
git_quiet -C "$V" commit --no-verify -am "a teammate's broken row"
echo "// more" >> "$V/internal/store/store.go"; git_quiet -C "$V" add -A
out=$(cd "$V" && sh .agents/kit/check.sh --staged --quiet 2>&1) &&
  ok "staged: someone else's dead path does not block" || bad "staged: someone else's dead path does not block" "$out"
printf "See \`alsogone/\`.\\n" >> "$V/cmd/api/AGENTS.md"; git_quiet -C "$V" add -A
out=$(cd "$V" && sh .agents/kit/check.sh --staged 2>&1)
[ $? -ne 0 ] && printf '%s' "$out" | grep -q "missing path: alsogone" && ! printf '%s' "$out" | grep -q "FAIL.*nope" &&
  ok "staged: only the map this commit edits blocks" || bad "staged: only the map this commit edits blocks" "$out"
git -C "$V" checkout -q HEAD -- cmd/api/AGENTS.md; git_quiet -C "$V" add -A
git_quiet -C "$V" commit -m "unrelated work" && ok "staged: the unrelated commit goes through" || bad "staged: the unrelated commit goes through"
expect_fail "full check still reports it" "$V" "names a missing path: nope"

V=$(variant removal); git_quiet -C "$V" rm -q go.mod
out=$(cd "$V" && sh .agents/kit/check.sh --staged --quiet 2>&1)
[ $? -ne 0 ] && printf '%s' "$out" | grep -q "missing path: go.mod" && ok "staged: deleting a mapped file blocks" || bad "staged: deleting a mapped file blocks" "$out"

V=$(variant longmap); i=0; while [ $i -lt 41 ]; do echo "line" >> "$V/cmd/api/AGENTS.md"; i=$((i + 1)); done
git_quiet -C "$V" commit --no-verify -am "long map"
echo "// more" >> "$V/internal/store/store.go"; git_quiet -C "$V" add -A
(cd "$V" && sh .agents/kit/check.sh --staged --quiet >/dev/null 2>&1) && ok "staged: a long map elsewhere does not block" || bad "staged: a long map elsewhere does not block"
echo "line" >> "$V/cmd/api/AGENTS.md"; git_quiet -C "$V" add -A
out=$(cd "$V" && sh .agents/kit/check.sh --staged --quiet 2>&1)
[ $? -ne 0 ] && printf '%s' "$out" | grep -q "(max 40)" && ok "staged: editing the long map blocks" || bad "staged: editing the long map blocks" "$out"

V=$(variant branch); git -C "$V" branch -q -M main; printf '| `nope/` | gone | |\n' >> "$V/AGENTS.md"
git_quiet -C "$V" commit --no-verify -am "broken on main"; git -C "$V" checkout -q -b feature
echo "// more" >> "$V/internal/store/store.go"; git_quiet -C "$V" commit -am "feature work"
out=$(cd "$V" && sh .agents/kit/check.sh --ci --since main 2>&1) && ok "CI --since: a branch is judged on its own changes" || bad "CI --since: a branch is judged on its own changes" "$out"

# --- CI and other setups ----------------------------------------------------
git clone -q "$WORK/go" "$WORK/clone" 2>/dev/null
expect_fail "fresh clone: the plain check asks for the hook" "$WORK/clone" "pre-commit check is not active"
out=$(cd "$WORK/clone" && sh .agents/kit/check.sh --ci 2>&1) && ok "fresh clone: --ci passes" || bad "fresh clone: --ci passes" "$out"
R="$WORK/crlf"; mkdir "$R" && git -C "$R" init -q   # copy mode, cloned where git writes CRLF (Windows)
PATH="$WORK/nolinks:$PATH" sh "$KIT/install.sh" "$R" > /dev/null 2>&1
printf '# crlf\n' > "$R/AGENTS.md"; echo "@AGENTS.md" > "$R/CLAUDE.md"; git_quiet -C "$R" add -A; git_quiet -C "$R" commit --no-verify -m init
git -c core.autocrlf=true clone -q "$R" "$WORK/crlf-clone" 2>/dev/null; git -C "$WORK/crlf-clone" config core.autocrlf true
out=$(cd "$WORK/crlf-clone" && sh .agents/kit/check.sh --ci 2>&1) && ok "copy mode: a CRLF clone keeps the skill copies equal" || bad "copy mode: a CRLF clone keeps the skill copies equal" "$out"
mkdir "$WORK/ci" && git -C "$WORK/ci" init -q && sh "$KIT/install.sh" --ci "$WORK/ci" > /dev/null 2>&1
grep -q "check.sh --ci" "$WORK/ci/.github/workflows/agent-kit.yml" 2>/dev/null && ok "--ci adds the GitHub Actions workflow" || bad "--ci adds the GitHub Actions workflow"

V=$(variant locals); echo '{}' > "$V/.claude/settings.local.json"
expect_pass "Claude Code's per-user settings are ignored" "$V"

mkdir "$WORK/ownhooks" && git -C "$WORK/ownhooks" init -q
printf '#!/bin/sh\nexit 0\n' > "$WORK/ownhooks/.git/hooks/pre-commit"; chmod +x "$WORK/ownhooks/.git/hooks/pre-commit"
sh "$KIT/install.sh" "$WORK/ownhooks" > "$WORK/ownhooks.log" 2>&1
[ -z "$(git -C "$WORK/ownhooks" config core.hooksPath)" ] && grep -q "own hooks in .git/hooks" "$WORK/ownhooks.log" &&
  ok "existing .git/hooks stay active" || bad "existing .git/hooks stay active" "$(cat "$WORK/ownhooks.log")"
mkdir "$WORK/precommitfw" && git -C "$WORK/precommitfw" init -q && echo "repos: []" > "$WORK/precommitfw/.pre-commit-config.yaml"
sh "$KIT/install.sh" "$WORK/precommitfw" > "$WORK/precommitfw.log" 2>&1
[ -z "$(git -C "$WORK/precommitfw" config core.hooksPath)" ] && grep -q "repo: local" "$WORK/precommitfw.log" &&
  ok "pre-commit framework: snippet printed, hooksPath untouched" || bad "pre-commit framework: snippet printed, hooksPath untouched" "$(cat "$WORK/precommitfw.log")"
printf '  - repo: local\n    hooks:\n      - id: a\n        entry: sh .agents/kit/check.sh --staged --quiet\n' >> "$WORK/precommitfw/.pre-commit-config.yaml"
out=$(cd "$WORK/precommitfw" && sh .agents/kit/check.sh 2>&1); printf '%s' "$out" | grep -q "pre-commit check is not active" &&
  bad "the pre-commit framework counts as an active hook" "$out" || ok "the pre-commit framework counts as an active hook"

FAKEKIT="$WORK/fakekit"; mkdir "$FAKEKIT"; echo "99.0.0" > "$FAKEKIT/VERSION"
out=$(cd "$WORK/go" && AGENT_KIT_HOME="$FAKEKIT" sh .agents/kit/check.sh 2>&1)
printf '%s' "$out" | grep -q "99.0.0 is available" && ok "a newer kit is noted" || bad "a newer kit is noted" "$out"

# --- Decisions, one file each -------------------------------------------------
V=$(variant decisions); mkdir -p "$V/docs/decisions"
printf -- '---\nid: D-001\nstatus: accepted\ndate: 2026-01-01\nsource_paths: [internal/store/]\n---\n\n# D-001: Use Go\n' > "$V/docs/decisions/D-001-use-go.md"
cp "$KIT/templates/docs/DECISIONS.md" "$V/DECISIONS.md"
expect_fail "a decision without an index row is caught" "$V" "D-001 (docs/decisions/D-001-use-go.md) has no row"
echo '| [D-001](docs/decisions/D-001-use-go.md) | Use Go | accepted | 2026-01-01 |' >> "$V/DECISIONS.md"
git_quiet -C "$V" add -A
expect_pass "decision files and their index pass" "$V"
edit 's/| accepted |/| proposed |/' "$V/DECISIONS.md"
expect_fail "a status that differs from the file is caught" "$V" 'D-001 is "accepted"'

# --- Helpers: stale docs, map rows --------------------------------------------
V=$(variant stale); echo "go 1.23" >> "$V/go.mod"; git_quiet -C "$V" commit --no-verify -am "bump go"
out=$(cd "$V" && sh .agents/kit/stale.sh)
printf '%s' "$out" | grep -q "^AGENTS.md.*go.mod" && ok "stale.sh: a map whose named file changed" || bad "stale.sh: a map whose named file changed" "$out"
printf '%s' "$out" | grep -q "^cmd/api/AGENTS.md" && bad "stale.sh: a map whose code did not change stays quiet" "$out" || ok "stale.sh: a map whose code did not change stays quiet"
out=$(cd "$WORK/go" && sh .agents/kit/map-rows.sh .)
printf '%s' "$out" | grep -q '| `internal/` |' && ! printf '%s' "$out" | grep -q 'go.mod' &&
  ok "map-rows.sh suggests only what the map lacks" || bad "map-rows.sh suggests only what the map lacks" "$out"

# --- Code written by hand: the catch-up queue ---------------------------------------
V=$(variant queue); q() { sh "$V/.agents/kit/queue.sh" count; }
echo "// by hand" >> "$V/internal/store/store.go"; git_quiet -C "$V" commit -am "hand edit"
[ "$(cd "$V" && q)" = 1 ] && ok "post-commit queues code committed without its docs" || bad "post-commit queues code committed without its docs" "$(cd "$V" && sh .agents/kit/queue.sh list)"
echo "// again" >> "$V/internal/store/store.go"; echo "More." >> "$V/internal/store/README.md"
git_quiet -C "$V" commit -am "edit with docs"
echo "// trivial" >> "$V/internal/store/store.go"; git_quiet -C "$V" commit -am "typo [no-docs]"
[ "$(cd "$V" && q)" = 1 ] && ok "commits with docs, or [no-docs], are not queued" || bad "commits with docs, or [no-docs], are not queued"
out=$(cd "$V" && echo '{}' | sh .agents/kit/session-start.sh)
printf '%s' "$out" | grep -q "catch-up" && ok "session start mentions the queue" || bad "session start mentions the queue" "$out"
(cd "$V" && sh .agents/kit/queue.sh done "$(git rev-parse HEAD~2)")
[ "$(cd "$V" && q)" = 0 ] && [ -z "$(cd "$V" && echo '{}' | sh .agents/kit/session-start.sh)" ] &&
  ok "an empty queue: session start says nothing" || bad "an empty queue: session start says nothing"

# --- Stop hook --------------------------------------------------------------
transcript() {  # transcript <file> <tool name>
  printf '%s\n' '{"type":"user","message":{"content":"go"}}' \
    "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"$2\",\"input\":{\"command\":\"x\"}}]}}" > "$1"
}
hook() {  # hook <repo> <transcript> <session> [--baseline]: the hook's output
  echo "{\"transcript_path\":\"$(native "$2")\",\"cwd\":\"$(native "$1/cmd")\",\"session_id\":\"$3\"}" |
    (cd "$1" && sh .agents/kit/stop-hook.sh ${4:-})
}
transcript "$WORK/bash.jsonl" Bash
transcript "$WORK/read.jsonl" Read

V=$(variant hookfail); printf '| `nope/` | gone | |\n' >> "$V/AGENTS.md"
hook "$V" "$WORK/bash.jsonl" s1 | grep -q '"block"' && ok "stop hook blocks after a shell edit that broke a map" || bad "stop hook blocks after a shell edit that broke a map"
out=$(hook "$WORK/go" "$WORK/bash.jsonl" s1)
[ -z "$out" ] && ok "stop hook passes a clean repo" || bad "stop hook passes a clean repo" "$out"

V=$(variant teamhook); printf '| `nope/` | gone | |\n' >> "$V/AGENTS.md"
git_quiet -C "$V" commit --no-verify -am "broken before the session"
hook "$V" "$WORK/read.jsonl" s2 --baseline
echo "// x" >> "$V/internal/store/store.go"
out=$(hook "$V" "$WORK/bash.jsonl" s2)
[ -z "$out" ] && ok "stop hook ignores problems the turn did not cause" || bad "stop hook ignores problems the turn did not cause" "$out"

V=$(variant remind); hook "$V" "$WORK/read.jsonl" s3 --baseline
out=$(hook "$V" "$WORK/read.jsonl" s3)
[ -z "$out" ] && ok "stop hook: nothing changed, nothing said" || bad "stop hook: nothing changed, nothing said" "$out"
echo "// x" >> "$V/cmd/api/main.go"
out=$(hook "$V" "$WORK/bash.jsonl" s3)
[ -z "$out" ] && ok "stop hook: an edit inside a mapped folder needs no reminder" || bad "stop hook: an edit inside a mapped folder needs no reminder" "$out"
echo "go 1.23" >> "$V/go.mod"
hook "$V" "$WORK/bash.jsonl" s3 | grep -q 'go.mod. is named in AGENTS.md' && ok "stop hook: a shell edit to a mapped file asks for the docs step" || bad "stop hook: a shell edit to a mapped file asks for the docs step"
echo "go 1.24" >> "$V/go.mod"
out=$(hook "$V" "$WORK/bash.jsonl" s3)
[ -z "$out" ] && ok "stop hook: asks only once per file" || bad "stop hook: asks only once per file" "$out"
printf 'package api\n' > "$V/cmd/api/routes.go"; echo "More." >> "$V/internal/store/README.md"
hook "$V" "$WORK/bash.jsonl" s3 | grep -q 'routes.go. was added to .cmd/api/' && ok "stop hook: a new file in a mapped folder asks; an unrelated README does not count" || bad "stop hook: a new file in a mapped folder asks; an unrelated README does not count"
printf 'package api\n' > "$V/cmd/api/server.go"; echo "Server." >> "$V/cmd/api/README.md"
out=$(hook "$V" "$WORK/bash.jsonl" s3)
[ -z "$out" ] && ok "stop hook: the README above the file satisfies it" || bad "stop hook: the README above the file satisfies it" "$out"

mkdir "$V/cmd/api/handlers"; printf 'package handlers\n' > "$V/cmd/api/handlers/a.go"; git_quiet -C "$V" add -A
git_quiet -C "$V" commit --no-verify -m handlers; hook "$V" "$WORK/read.jsonl" s3 --baseline
printf 'package handlers\n' > "$V/cmd/api/handlers/b.go"
out=$(hook "$V" "$WORK/bash.jsonl" s3)
[ -z "$out" ] && ok "stop hook: a file added deeper in an existing folder needs no reminder" || bad "stop hook: a file added deeper in an existing folder needs no reminder" "$out"

V=$(variant learnhook); mkdir "$V/learning_docs"
printf -- '---\ntitle: API\nsource_paths: [cmd/api/]\nsource_commit: abc\n---\n# API\n' > "$V/learning_docs/01-api.md"
hook "$V" "$WORK/read.jsonl" s4 --baseline
echo "// x" >> "$V/cmd/api/main.go"
out=$(hook "$V" "$WORK/bash.jsonl" s4)
[ -z "$out" ] && grep -q "learning_docs/01-api.md" "$V/.git/agent-kit/stale-learning" &&
  ok "stop hook: stale learning docs are noted, never blocking" || bad "stop hook: stale learning docs are noted, never blocking" "$out"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
