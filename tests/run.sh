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

write_map() {  # write_map <folder> <one-line purpose>: AGENTS.md + README.agentk.md + CLAUDE.md
  printf '# %s\n\n%s\n\n## Further reading\n\n- `README.agentk.md` — details\n' "$(basename "$1")" "$2" > "$1/AGENTS.md"
  printf '# %s\n\n%s\n' "$(basename "$1")" "$2" > "$1/README.agentk.md"
  echo "@AGENTS.md" > "$1/CLAUDE.md"
}

# --- Empty repo -------------------------------------------------------------
new_repo empty
R="$WORK/empty"
expect_fail "empty repo: install alone asks for the root map" "$R" "AGENTS.md is missing"
# A link on macOS and Linux; a copy where symlinks fail (Windows).
grep -qE "linked .claude/skills|copied .agents/skills -> .claude/skills" "$WORK/empty.install.log" &&
  ok "install creates .claude/skills" || bad "install creates .claude/skills" "$(cat "$WORK/empty.install.log")"
printf '# empty\n\nA new project.\n\n| Path | What | Read first |\n|---|---|---|\n| `DECISIONS.agentk.md` | Lineage | |\n' > "$R/AGENTS.md"
echo "@AGENTS.md" > "$R/CLAUDE.md"
cp "$KIT/templates/docs/DECISIONS.md" "$R/DECISIONS.agentk.md"
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
expect_fail "new unit folder is noticed" "$V" "internal/cache has no README.agentk.md"

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
  cp "$KIT/templates/docs/DECISIONS.md" "$R/DECISIONS.agentk.md"
  mkdir -p "$R/learning_docs" "$R/svc"; echo "# Overview" > "$R/learning_docs/00-overview.agentk.md"
  echo "# Svc" > "$R/svc/README.agentk.md"; echo "# Ours" > "$R/README.md"
  echo "package main" > "$R/main.go"
  git_quiet -C "$R" add -A
}
staged() { git -C "$1" diff --cached --name-only; }  # staged <repo>
has() { staged "$1" | grep -qx "$2"; }               # has <repo> <path>

mode_repo agent; R="$WORK/mode-agent"
expect_pass "share agent: checks pass" "$R"
has "$R" AGENTS.md && has "$R" .agents/kit/check.sh && ! has "$R" learning_docs/00-overview.agentk.md &&
  ok "share agent: agent files staged, learning docs not" || bad "share agent: agent files staged, learning docs not" "$(staged "$R")"

mode_repo all; R="$WORK/mode-all"
expect_pass "share all: checks pass" "$R"
has "$R" AGENTS.md && has "$R" learning_docs/00-overview.agentk.md &&
  ok "share all: agent files and learning docs staged" || bad "share all: agent files and learning docs staged" "$(staged "$R")"

mode_repo learning; R="$WORK/mode-learning"
expect_pass "share learning: checks pass" "$R"
has "$R" learning_docs/00-overview.agentk.md && has "$R" main.go && has "$R" README.md && [ -z "$(staged "$R" | grep -E '\.agentk\.md$' | grep -v '^learning_docs/')" ] && [ -z "$(staged "$R" | grep -E '^(AGENTS|CLAUDE|DECISIONS)\.md$|^\.(agents|claude|codex|githooks)/|^\.git(ignore|attributes)$')" ] &&
  ok "share learning: learning docs staged, no agent file or kit rule" || bad "share learning: learning docs staged, no agent file or kit rule" "$(staged "$R")"
git_quiet -C "$R" commit -m first && ok "share learning: pre-commit runs from local files" || bad "share learning: pre-commit runs from local files"

mode_repo none; R="$WORK/mode-none"
expect_pass "share none: checks pass" "$R"
[ "$(staged "$R" | tr '\n' ' ')" = "README.md main.go " ] && ok "share none: only code and your README are staged" || bad "share none: only code and your README are staged" "$(staged "$R")"
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
(cd "$V" && set -f && git rm -r --cached -q --ignore-unmatch -- AGENTS.md ':(glob)**/AGENTS.md' CLAUDE.md ':(glob)**/CLAUDE.md' DECISIONS.agentk.md PLAN.agentk.md ':(glob)**/*.agentk.md' .agents .claude .codex .githooks .gitattributes 2>/dev/null; true)
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
[ ! -e "$V/.agents/skills/scaffold.kit-new" ] && [ -z "$(ls "$V/.agents/skills" | grep -v -E '^(docs-sync|learning-docs|lineage|scaffold|catch-up|wrap-up|explain-diff|explain-d-ez|explain-d-in)$')" ] &&
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
mkdir -p "$R/svc"; printf '# svc\n' > "$R/svc/README.agentk.md"
edit 's/^OWN_SKILLS=.*/OWN_SKILLS="lineage"/' "$R/.agents/agent-kit.conf"
before=$(git -C "$R" status --porcelain | cksum)
out=$(sh "$KIT/templates/kit/inventory.sh" "$R")
after=$(git -C "$R" status --porcelain | cksum)
printf '%s' "$out" | grep -q "^Kit docs: maps, pointer files and \*.agentk.md" && printf '%s' "$out" | grep -q "^Rules for other agents" &&
  printf '%s' "$out" | grep -q "lineage .*repo-owned (OWN_SKILLS)" && printf '%s' "$out" | grep -q "docs-sync .*same name as a kit skill" &&
  printf '%s' "$out" | grep -q "NOTES.md  \[untracked" &&
  [ "$(printf '%s\n' "$out" | awk '/^Kit docs/ { g = 1 } /^Other Markdown/ { g = 2 } /svc\/README.agentk.md/ { print g }')" = 1 ] && ok "inventory groups maps, rules, skills and stray docs" || bad "inventory groups maps, rules, skills and stray docs" "$out"
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
expect_fail "a unit past the threshold needs its map" "$R" "pkgs/big has no README.agentk.md"
echo "# Big, by people" > "$R/pkgs/big/README.md"
expect_fail "the people's README.md does not stand in for the kit's detail doc" "$R" "pkgs/big has no README.agentk.md"
rm "$R/pkgs/big/README.md"
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
printf -- '---\nid: D-001\nstatus: accepted\ndate: 2026-01-01\nsource_paths: [internal/store/]\n---\n\n# D-001: Use Go\n' > "$V/docs/decisions/D-001-use-go.agentk.md"
cp "$KIT/templates/docs/DECISIONS.md" "$V/DECISIONS.agentk.md"
expect_fail "a decision without an index row is caught" "$V" "D-001 (docs/decisions/D-001-use-go.agentk.md) has no row in DECISIONS.agentk.md"
echo '| [D-001](docs/decisions/D-001-use-go.agentk.md) | Use Go | accepted | 2026-01-01 |' >> "$V/DECISIONS.agentk.md"
git_quiet -C "$V" add -A
expect_pass "decision files and their index pass" "$V"
edit 's/| accepted |/| proposed |/' "$V/DECISIONS.agentk.md"
expect_fail "a status that differs from the file is caught" "$V" 'D-001 is "accepted"'

# --- Kit docs end in .agentk.md; your Markdown stays yours ------------------
V=$(variant oldnames)   # a kit 0.5 config: no DOC_SUFFIX, plain names
edit '/^DOC_SUFFIX=/d' "$V/.agents/agent-kit.conf"
for u in cmd/api internal/store; do
  git -C "$V" mv -f "$u/README.agentk.md" "$u/README.md"; edit 's/README\.agentk\.md/README.md/' "$V/$u/AGENTS.md"
done
printf -- '---\nid: D-001\nstatus: accepted\ndate: 2026-01-01\n---\n# D-001\n' > "$V/docs-d.tmp"
mkdir -p "$V/docs/decisions"; mv "$V/docs-d.tmp" "$V/docs/decisions/D-001-x.md"
cp "$KIT/templates/docs/DECISIONS.md" "$V/DECISIONS.md"; echo '| [D-001](docs/decisions/D-001-x.md) | X | accepted | 2026-01-01 |' >> "$V/DECISIONS.md"
git_quiet -C "$V" add -A
expect_pass "without DOC_SUFFIX the kit 0.5 names still pass" "$V"

V=$(variant fixednames); git -C "$V" mv cmd/api/CLAUDE.md cmd/api/CLAUDE.agentk.md
expect_fail "a pointer file with the suffix is caught" "$V" "cmd/api/CLAUDE.agentk.md must keep its exact name"

mkdir "$WORK/ownreadme" && git -C "$WORK/ownreadme" init -q
mkdir -p "$WORK/ownreadme/svc"; echo "# Ours" > "$WORK/ownreadme/README.md"; echo "# Svc, ours" > "$WORK/ownreadme/svc/README.md"
echo "# Guide" > "$WORK/ownreadme/CONTRIBUTING.md"
before=$(cd "$WORK/ownreadme" && cat README.md svc/README.md CONTRIBUTING.md | cksum)
sh "$KIT/install.sh" "$WORK/ownreadme" > /dev/null 2>&1; sh "$KIT/install.sh" --share none "$WORK/ownreadme" > /dev/null 2>&1
sh "$KIT/install.sh" --share agent "$WORK/ownreadme" > /dev/null 2>&1
after=$(cd "$WORK/ownreadme" && cat README.md svc/README.md CONTRIBUTING.md | cksum)
[ "$before" = "$after" ] && ok "install and upgrades never touch your Markdown files" || bad "install and upgrades never touch your Markdown files"

V=$(variant oldstyle); echo "x" > "$V/.agents/kit/writing-style.md"; sh "$KIT/install.sh" "$V" > /dev/null 2>&1
[ ! -e "$V/.agents/kit/writing-style.md" ] && [ -f "$V/.agents/kit/writing-style.agentk.md" ] &&
  ok "upgrade replaces writing-style.md with writing-style.agentk.md" || bad "upgrade replaces writing-style.md with writing-style.agentk.md"

V=$(variant yourreadme); echo "// x" >> "$V/internal/store/store.go"; echo "# Store, ours" > "$V/internal/store/README.md"
git_quiet -C "$V" add -A; git_quiet -C "$V" commit -m "code and our README"
[ "$(cd "$V" && sh .agents/kit/queue.sh count)" = 0 ] && ok "queue: updating your own README counts as docs" || bad "queue: updating your own README counts as docs"
echo "// y" >> "$V/internal/store/store.go"; echo "More." >> "$V/internal/store/README.md"
echo "x" >> "$V/internal/store/README.agentk.md"; git_quiet -C "$V" commit --no-verify -am "more"
echo "// z" >> "$V/internal/store/store.go"; git_quiet -C "$V" commit --no-verify -am "code only"
out=$(cd "$V" && sh .agents/kit/stale.sh)
printf '%s' "$out" | grep -q "^internal/store/README.agentk.md	.*	kit$" && printf '%s' "$out" | grep -q "^internal/store/README.md	.*	yours$" &&
  ok "stale.sh labels kit docs and your docs" || bad "stale.sh labels kit docs and your docs" "$out"

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
echo "// again" >> "$V/internal/store/store.go"; echo "More." >> "$V/internal/store/README.agentk.md"
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
printf 'package api\n' > "$V/cmd/api/routes.go"; echo "More." >> "$V/internal/store/README.agentk.md"
hook "$V" "$WORK/bash.jsonl" s3 | grep -q 'routes.go. was added to .cmd/api/' && ok "stop hook: a new file in a mapped folder asks; an unrelated README does not count" || bad "stop hook: a new file in a mapped folder asks; an unrelated README does not count"
printf 'package api\n' > "$V/cmd/api/server.go"; echo "Server." >> "$V/cmd/api/README.agentk.md"
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

# --- Team repos: work beside the team's AGENTS.md / CLAUDE.md, locally -------
TR="$WORK/teamrepo"; mkdir -p "$TR"; git init -q --bare "$TR/remote.git"
git -C "$TR/remote.git" symbolic-ref HEAD refs/heads/main
M="$TR/mate"; git clone -q "$TR/remote.git" "$M" 2>/dev/null
mkdir -p "$M/svc/api" "$M/.claude/skills/deploy"; echo 'x = 1' > "$M/svc/api/app.py"
printf '# Team rules\n\nUse make.\n' > "$M/AGENTS.md"; printf '# Claude, team\n' > "$M/CLAUDE.md"
printf '# API, team\n' > "$M/svc/api/AGENTS.md"; printf -- '---\nname: deploy\n---\nDeploy.\n' > "$M/.claude/skills/deploy/SKILL.md"
printf 'node_modules/\n' > "$M/.gitignore"
mate() { git -c user.name=mate -c user.email=mate@team.com -C "$M" "$@" >/dev/null 2>&1; }
mate add -A; mate commit -m team; mate push origin HEAD:refs/heads/main
B="$TR/me"; git clone -q "$TR/remote.git" "$B" 2>/dev/null
git -C "$B" config user.email me@me.com; git -C "$B" config user.name me
team_sum() { (cd "$B" && cat AGENTS.md CLAUDE.md svc/api/AGENTS.md .gitignore .claude/skills/deploy/SKILL.md | cksum); }
before=$(team_sum)

out=$(sh "$KIT/templates/kit/agent-files.sh" "$B")
printf '%s' "$out" | grep -q "TEAM REPO" && printf '%s' "$out" | grep -q "TEAM FILE: other people wrote it and it is on the remote" &&
  ok "agent-files: a team repo and its team files are recognised" || bad "agent-files: a team repo and its team files are recognised" "$out"
echo "# mine" > "$B/GEMINI.md"
out=$(sh "$KIT/templates/kit/agent-files.sh" "$B"); printf '%s' "$out" | grep -q "YOURS: it exists only on this computer" &&
  ok "agent-files: an untracked file is yours" || bad "agent-files: an untracked file is yours"
rm "$B/GEMINI.md"
V=$(variant personal); git -C "$V" config user.email test@example.com
out=$(sh "$KIT/templates/kit/agent-files.sh" "$V"); printf '%s' "$out" | grep -q "PERSONAL REPO" && ok "agent-files: a one-author repo is personal" || bad "agent-files: a one-author repo is personal"

sh "$KIT/install.sh" --maps beside "$B" > "$WORK/beside.log" 2>&1
[ "$before" = "$(team_sum)" ] && [ -z "$(git -C "$B" status --porcelain)" ] &&
  ok "beside: install leaves team files untouched and git status clean" || bad "beside: install leaves team files untouched and git status clean" "$(git -C "$B" status --porcelain; cat "$WORK/beside.log")"
grep -q '^MAPS="beside"' "$B/.agents/agent-kit.conf" && grep -q '^SHARE="none"' "$B/.agents/agent-kit.conf" &&
  ok "beside: forces SHARE=none" || bad "beside: forces SHARE=none"
[ -f "$B/.claude/skills/deploy/SKILL.md" ] && [ -f "$B/.claude/skills/lineage/.agent-kit" ] && [ -f "$B/.claude/settings.local.json" ] && [ ! -e "$B/.claude/settings.json" ] &&
  ok "beside: kit skills sit beside the team's; hooks go in settings.local.json" || bad "beside: kit skills sit beside the team's; hooks go in settings.local.json"

echo "My own note." > "$B/CLAUDE.local.md"
printf '# me\n\n| Path | What | Read first |\n|---|---|---|\n| `svc/api/` | API | `svc/api/AGENTS.agentk.md` |\n' > "$B/AGENTS.agentk.md"
printf '# api, mine\n\n| Path | What |\n|---|---|\n| `app.py` | entry |\n' > "$B/svc/api/AGENTS.agentk.md"
expect_fail "beside: missing wiring is caught" "$B" "local wiring of your maps is stale or missing"
(cd "$B" && sh .agents/kit/wire.sh >/dev/null)
expect_pass "beside: wired maps pass" "$B"
grep -q '^@AGENTS.md$' "$B/svc/api/CLAUDE.local.md" && grep -q '^@AGENTS.agentk.md$' "$B/svc/api/CLAUDE.local.md" &&
  ! grep -q '^@AGENTS.md$' "$B/CLAUDE.local.md" && grep -q '^My own note.$' "$B/CLAUDE.local.md" &&
  ok "beside: CLAUDE.local.md imports the team AGENTS.md only where no CLAUDE.md, and keeps your lines" || bad "beside: CLAUDE.local.md imports the team AGENTS.md only where no CLAUDE.md, and keeps your lines" "$(cat "$B/CLAUDE.local.md" "$B/svc/api/CLAUDE.local.md")"
t=$(grep -n 'API, team' "$B/svc/api/AGENTS.override.md" | cut -d: -f1); m=$(grep -n 'api, mine' "$B/svc/api/AGENTS.override.md" | cut -d: -f1)
[ -n "$t" ] && [ -n "$m" ] && [ "$t" -lt "$m" ] && ok "beside: the Codex override has the team's rules first" || bad "beside: the Codex override has the team's rules first" "$(cat "$B/svc/api/AGENTS.override.md")"
[ -z "$(git -C "$B" add -A --dry-run)" ] && ok "beside: git add -A stages nothing of yours" || bad "beside: git add -A stages nothing of yours" "$(git -C "$B" add -A --dry-run)"

printf '\nAlways run tests.\n' >> "$M/svc/api/AGENTS.md"; mate commit -am rule; mate push origin HEAD:refs/heads/main
git -C "$B" pull -q 2>/dev/null
grep -q 'Always run tests' "$B/svc/api/AGENTS.override.md" && ok "beside: git pull refreshes the Codex override" || bad "beside: git pull refreshes the Codex override"
echo "Local edit." >> "$B/svc/api/AGENTS.md"
expect_fail "beside: a stale override is caught" "$B" "local wiring of your maps is stale"
git -C "$B" checkout -q -- svc/api/AGENTS.md; (cd "$B" && sh .agents/kit/wire.sh --quiet)
expect_pass "beside: rewired after the team file changes" "$B"

printf '| `gone.py` | x |\n' >> "$B/svc/api/AGENTS.agentk.md"; (cd "$B" && sh .agents/kit/wire.sh --quiet)
expect_fail "beside: your unit map is checked like any map" "$B" "names a missing path: gone.py"
edit '/gone.py/d' "$B/svc/api/AGENTS.agentk.md"; (cd "$B" && sh .agents/kit/wire.sh --quiet)

git -C "$B" add -f AGENTS.agentk.md
expect_fail "beside: a force-added map is caught" "$B" "would reach the team's repo"
if git -C "$B" commit -qm leak >/dev/null 2>&1; then bad "beside: the commit of your map is blocked"; else ok "beside: the commit of your map is blocked"; fi
git -C "$B" rm -q --cached AGENTS.agentk.md

edit 's/^SHARE=.*/SHARE="agent"/' "$B/.agents/agent-kit.conf"
expect_fail "beside: a shared mode is refused" "$B" "MAPS=beside keeps your setup on this computer"
edit 's/^SHARE=.*/SHARE="none"/' "$B/.agents/agent-kit.conf"

mkdir -p "$B/svc/lib"; printf '# lib, mine\n' > "$B/svc/lib/AGENTS.agentk.md"; echo "team override" > "$B/svc/lib/AGENTS.override.md"
git -C "$B" add -f svc/lib/AGENTS.override.md; git -C "$B" commit -q --no-verify -m "team override" >/dev/null 2>&1
out=$(cd "$B" && sh .agents/kit/wire.sh --plan); (cd "$B" && sh .agents/kit/wire.sh --quiet)
printf '%s' "$out" | grep -q "skip .*svc/lib/AGENTS.override.md" && [ "$(cat "$B/svc/lib/AGENTS.override.md")" = "team override" ] &&
  ok "beside: a tracked AGENTS.override.md is never written" || bad "beside: a tracked AGENTS.override.md is never written" "$out"
expect_pass "beside: a team's tracked override is not a leak" "$B"
git -C "$B" reset -q --hard HEAD~1; rm -rf "$B/svc/lib"; (cd "$B" && sh .agents/kit/wire.sh --quiet)

NL="$TR/nolinks"; git clone -q "$TR/remote.git" "$NL" 2>/dev/null; rm -rf "$NL/.claude"; git_quiet -C "$NL" commit --no-verify -qam "no skills"
PATH="$WORK/nolinks:$PATH" sh "$KIT/install.sh" --maps beside "$NL" > /dev/null 2>&1
[ -f "$NL/.claude/skills/lineage/.agent-kit" ] && [ -z "$(git -C "$NL" status --porcelain)" ] &&
  ok "beside without symlinks: marked skill copies, nothing to commit" || bad "beside without symlinks: marked skill copies, nothing to commit" "$(git -C "$NL" status --porcelain)"

edit 's/^AGENTS_USED=.*/AGENTS_USED="claude codex gemini"/' "$B/.agents/agent-kit.conf"; mkdir -p "$WORK/ghome"
HOME="$WORK/ghome" sh -c "cd '$B' && sh .agents/kit/wire.sh --plan" | grep -q "gemini  todo" && ok "beside: Gemini setting is offered" || bad "beside: Gemini setting is offered"
mkdir -p "$B/.gemini"; echo '{"context": {"fileName": ["AGENTS.md"]}}' > "$B/.gemini/settings.json"; git -C "$B" add -f .gemini/settings.json
HOME="$WORK/ghome" sh -c "cd '$B' && sh .agents/kit/wire.sh --plan" | grep -q "gemini  limit" && ok "beside: a team Gemini setting is reported as a limit" || bad "beside: a team Gemini setting is reported as a limit"
git -C "$B" rm -q --cached .gemini/settings.json; rm -rf "$B/.gemini"
edit 's/^AGENTS_USED=.*/AGENTS_USED="claude codex"/' "$B/.agents/agent-kit.conf"

mkdir -p "$B/cmd"; hook "$B" "$WORK/read.jsonl" t1 --baseline
echo "edit" >> "$B/AGENTS.md"
hook "$B" "$WORK/bash.jsonl" t1 | grep -q 'belong to the team' && ok "beside: the Stop hook asks once when the team's AGENTS.md is edited" || bad "beside: the Stop hook asks once when the team's AGENTS.md is edited"
git -C "$B" checkout -q -- AGENTS.md

out=$(cd "$B" && sh .agents/kit/stale.sh since HEAD~1)
printf '%s' "$out" | grep -q "^svc/api/AGENTS.agentk.md	.*svc/api/AGENTS.md (team rules)" &&
  ok "beside: stale.sh flags your map when the team's file there changed" || bad "beside: stale.sh flags your map when the team's file there changed" "$out"

(cd "$B" && sh .agents/kit/wire.sh --remove >/dev/null)
[ ! -e "$B/svc/api/CLAUDE.local.md" ] && [ ! -e "$B/svc/api/AGENTS.override.md" ] && [ "$(cat "$B/CLAUDE.local.md")" = "My own note." ] &&
  [ -f "$B/svc/api/AGENTS.agentk.md" ] && [ "$before" != "" ] &&
  ok "beside: --remove deletes only what the kit made" || bad "beside: --remove deletes only what the kit made"

# --- 0.8 fixes ----------------------------------------------------------------
NOREPO="$WORK/norepo"; mkdir -p "$NOREPO"
for script in session-start.sh stop-hook.sh; do
  cmd=$(sed -n "s/^ *\"command\": \"\(.*kit\/$script.*\)\"\$/\1/p" "$KIT/templates/config/claude-settings.json" | sed 's/\\"/"/g')
  out=$(cd "$NOREPO" && GIT_CEILING_DIRECTORIES="$WORK" sh -c "$cmd" < /dev/null 2>&1); code=$?
  [ "$code" = 0 ] && [ -z "$out" ] && ok "hook command for $script: silent outside a git repo" ||
    bad "hook command for $script: silent outside a git repo" "exit $code: $out"
done

new_repo oldhooks; R="$WORK/oldhooks"
printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"sh -c '"'"'sh \\"$(git rev-parse --show-toplevel)/.agents/kit/stop-hook.sh\\"'"'"'"}]}]}}\n' > "$R/.claude/settings.json"
sh "$KIT/install.sh" "$R" > /dev/null 2>&1
grep -q 'exec sh' "$R/.claude/settings.json" && ! grep -q 'sh -c .sh \\"' "$R/.claude/settings.json" &&
  ok "upgrade swaps the old kit hook command" || bad "upgrade swaps the old kit hook command" "$(cat "$R/.claude/settings.json")"

[ -z "$(git -C "$WORK/oldhooks" diff --cached --name-only)" ] &&
  ok "install stages nothing in a fresh repo" || bad "install stages nothing in a fresh repo" "$(git -C "$WORK/oldhooks" diff --cached --name-only)"

new_repo queue8; R="$WORK/queue8"
mkdir -p "$R/pkg/sub dir"; echo x > "$R/pkg/__init__.py"; echo y > "$R/pkg/sub dir/my file.py"
git_quiet -C "$R" add -A; git_quiet -C "$R" commit --no-verify -m pkg
(cd "$R" && sh .agents/kit/queue.sh add HEAD)
(cd "$R" && sh .agents/kit/queue.sh list) | grep -q ' 2-files ' &&
  ok "queue counts __init__.py and paths with spaces" || bad "queue counts __init__.py and paths with spaces" "$(cd "$R" && sh .agents/kit/queue.sh list)"

printf 'MAP_EXEMPT="$HOME`echo x`"\r\n' >> "$R/.agents/agent-kit.conf"
val=$(cd "$R" && sh -c '. ./.agents/kit/lib.sh && load_conf && printf "%s" "$MAP_EXEMPT"')
[ "$val" = '$HOME`echo x`' ] && ok "config values are read as text, never run" || bad "config values are read as text, never run" "$val"

out=$(sh "$KIT/install.sh" --share 2>&1); code=$?
[ "$code" != 0 ] && printf '%s' "$out" | grep -q 'needs a value' &&
  ok "install --share without a value names the fix" || bad "install --share without a value names the fix" "$out"

V=$(variant suffixword); printf 'Kit docs end in `.agentk.md`.\n' >> "$V/AGENTS.md"
expect_pass "a map may name the kit's name ending (.agentk.md)" "$V"

# --- Team pulls: other people's commits since the docs were last checked -------
PR="$WORK/pulls"; mkdir -p "$PR"; git init -q --bare "$PR/remote.git"
git -C "$PR/remote.git" symbolic-ref HEAD refs/heads/main
P1="$PR/mate"; git clone -q "$PR/remote.git" "$P1" 2>/dev/null
mate2() { git -c user.name=mate -c user.email=mate@team.com -C "$P1" "$@" >/dev/null 2>&1; }
echo 'x = 1' > "$P1/app.py"; mate2 add -A; mate2 commit -m start; mate2 push origin HEAD:refs/heads/main
P2="$PR/me"; git clone -q "$PR/remote.git" "$P2" 2>/dev/null
git -C "$P2" config user.email me@me.com; git -C "$P2" config user.name me
sh "$KIT/install.sh" "$P2" > /dev/null 2>&1
[ -z "$(cd "$P2" && echo '{}' | sh .agents/kit/session-start.sh | grep 'other people')" ] &&
  ok "pulls: the first session sets the mark and says nothing" || bad "pulls: the first session sets the mark and says nothing"
echo 'y = 2' >> "$P1/app.py"; mate2 commit -am "mate changes app"; echo 'notes' > "$P1/NOTES.txt"; mate2 add -A; mate2 commit -m "mate notes"
mate2 push origin HEAD:refs/heads/main
out=$(git -C "$P2" pull -q --no-rebase origin main 2>&1)
printf '%s' "$out" | grep -q '1 commit(s) from other people' &&
  ok "pulls: post-merge says what arrived (code commits only)" || bad "pulls: post-merge says what arrived (code commits only)" "$out"
out=$(cd "$P2" && echo '{}' | sh .agents/kit/session-start.sh)
printf '%s' "$out" | grep -q 'docs-sync skill with scope pulled' &&
  ok "pulls: the session start offers docs-sync scope pulled" || bad "pulls: the session start offers docs-sync scope pulled" "$out"
base=$(cd "$P2" && sh .agents/kit/pulled.sh base)
[ "$(git -C "$P2" rev-parse HEAD~2)" = "$base" ] && ok "pulls: base is the commit before the pull" || bad "pulls: base is the commit before the pull" "$base"
(cd "$P2" && sh .agents/kit/pulled.sh done)
[ "$(cd "$P2" && sh .agents/kit/pulled.sh count)" = 0 ] && ok "pulls: done clears it" || bad "pulls: done clears it"
echo 'z = 3' >> "$P2/app.py"; git_quiet -C "$P2" -c user.email=me@me.com commit --no-verify -am mine
[ "$(cd "$P2" && sh .agents/kit/pulled.sh count)" = 0 ] && ok "pulls: your own commits never count" || bad "pulls: your own commits never count"

# --- Multi-repo workspaces ------------------------------------------------------
export AGENT_KIT_STATE="$WORK/kit-state"
WS="$WORK/ws"; mkdir -p "$WS"
for r in front back legacy; do
  git init -q "$WS/$r"; echo 'x = 1' > "$WS/$r/app.py"; git_quiet -C "$WS/$r" add -A; git_quiet -C "$WS/$r" commit -m init
done
sh "$KIT/install.sh" "$WS/front" > /dev/null 2>&1
printf '# front\n\nThe web app.\n' > "$WS/front/AGENTS.md"; echo "@AGENTS.md" > "$WS/front/CLAUDE.md"
mkdir -p "$WS/front/src/api"; echo 'y = 1' > "$WS/front/src/api/client.py"
git_quiet -C "$WS/front" add -A; git_quiet -C "$WS/front" commit --no-verify -m kit
legacy_sum=$(cd "$WS/legacy" && git status --porcelain | cksum)
out=$(cd "$WS" && sh "$KIT/templates/workspace/workspace.sh" init --name shop 2>&1)
[ -f "$WS/WORKSPACE.agentk.md" ] && grep -q '@WORKSPACE.agentk.md' "$WS/CLAUDE.md" && grep -qF "$WS" "$AGENT_KIT_STATE/workspaces" &&
  printf '%s' "$out" | grep -q 'Waiting for an answer about the kit: back legacy' &&
  ok "workspace: init writes the map and pointers, registers, and lists repos without an answer" || bad "workspace: init writes the map and pointers, registers, and lists repos without an answer" "$out"
grep -q '| `front/` | _say what it is_ | kit .*, own | `front/AGENTS.md` |' "$WS/WORKSPACE.agentk.md" &&
  ok "workspace: the repo table names each repo's kit and map" || bad "workspace: the repo table names each repo's kit and map" "$(cat "$WS/WORKSPACE.agentk.md")"
sed 's/| `back\/` | _say what it is_ |/| `back\/` | The API |/' "$WS/WORKSPACE.agentk.md" > "$WS/m.tmp" && mv "$WS/m.tmp" "$WS/WORKSPACE.agentk.md"
(cd "$WS" && sh .agent-workspace/kit/workspace.sh decline legacy > /dev/null)
grep -q '| `back/` | The API |' "$WS/WORKSPACE.agentk.md" && grep -q '| `legacy/` | _say what it is_ | declined |' "$WS/WORKSPACE.agentk.md" &&
  ok "workspace: a refresh keeps the Role people wrote" || bad "workspace: a refresh keeps the Role people wrote" "$(cat "$WS/WORKSPACE.agentk.md")"
[ -f "$WS/legacy/.git/agent-kit/declined" ] && [ "$(cd "$WS/legacy" && git status --porcelain | cksum)" = "$legacy_sum" ] &&
  ok "workspace: never installing writes only inside .git" || bad "workspace: never installing writes only inside .git"

(cd "$WS/front" && sh .agents/kit/wire.sh > /dev/null)
grep -q '\.\./WORKSPACE.agentk.md' "$WS/front/AGENTS.override.md" && grep -q 'The web app' "$WS/front/AGENTS.override.md" &&
  [ -z "$(git -C "$WS/front" status --porcelain -- AGENTS.override.md)" ] &&
  ok "workspace: Codex gets a local override with the workspace pointer (own mode)" || bad "workspace: Codex gets a local override with the workspace pointer (own mode)"

WS2="$WORK/ws2"; mkdir -p "$WS2"
(cd "$WS2" && sh "$KIT/templates/workspace/workspace.sh" init > /dev/null 2>&1)
out=$(cd "$WS2" && sh .agent-workspace/kit/workspace.sh add "$WS/back" 2>&1)
[ -f "$WS2/back/.git" ] && printf '%s' "$out" | grep -q 'also in' &&
  ok "workspace: add makes a worktree and names the other workspace" || bad "workspace: add makes a worktree and names the other workspace" "$out"
[ "$(cd "$WS/back" && sh "$WS/.agent-workspace/kit/workspace.sh" where | wc -l | tr -d ' ')" = 2 ] &&
  ok "workspace: where lists both workspaces" || bad "workspace: where lists both workspaces" "$(cd "$WS/back" && sh "$WS/.agent-workspace/kit/workspace.sh" where)"
git init -q "$WORK/elsewhere"; ln -s "$WORK/elsewhere" "$WS2/linked" 2>/dev/null
if [ -L "$WS2/linked" ]; then
  (cd "$WS2" && sh .agent-workspace/kit/workspace.sh scan) | grep -q 'linked .*symlink: not supported' &&
    ok "workspace: a symlinked repo is reported with its fix" || bad "workspace: a symlinked repo is reported with its fix"
fi
mkdir -p "$WS2/copied"; git init -q "$WS2/copied"
(cd "$WS2" && sh .agent-workspace/kit/workspace.sh repos) | grep -q "^copied	none" &&
  ok "workspace: a repo dropped in by hand is found" || bad "workspace: a repo dropped in by hand is found"

printf 'LINKS="back:api.yaml>front:src/api"\n' >> "$WS/.agent-workspace/workspace.conf"
ev="{\"session_id\":\"w1\",\"cwd\":\"$(native "$WS")\"}"
out=$(echo "$ev" | sh "$WS/.agent-workspace/kit/ws-hook.sh" session-start)
printf '%s' "$out" | grep -q 'no answer yet about the kit for: back\.' &&
  ok "workspace: session start names repos without an answer" || bad "workspace: session start names repos without an answer" "$out"
echo 'openapi: 3' > "$WS/back/api.yaml"; echo '# x' >> "$WS/front/src/api/client.py"
out=$(echo "$ev" | sh "$WS/.agent-workspace/kit/ws-hook.sh" stop)
printf '%s' "$out" | grep -q 'back/api.yaml. changed, and .front/src/api. uses it' &&
  ok "workspace: the Stop hook names the consumer when a LINKS provider changes" || bad "workspace: the Stop hook names the consumer when a LINKS provider changes" "$out"
out=$(echo "$ev" | sh "$WS/.agent-workspace/kit/ws-hook.sh" stop)
[ -z "$out" ] && ok "workspace: each link is named once per session" || bad "workspace: each link is named once per session" "$out"
out=$(cd "$WORK/norepo" && sh "$KIT/templates/workspace/workspace.sh" scan 2>&1)
printf '%s' "$out" | grep -q 'fix: run' && ok "workspace: outside a workspace, scan names the fix" || bad "workspace: outside a workspace, scan names the fix" "$out"
unset AGENT_KIT_STATE

# --- Explanation skills ----------------------------------------------------------
R="$WORK/go"
for skill in explain-d-ez explain-d-in; do
  [ -f "$R/.agents/skills/$skill/SKILL.md" ] && [ -f "$R/.claude/skills/$skill/SKILL.md" ] &&
    grep -q "^name: $skill\$" "$R/.agents/skills/$skill/SKILL.md" &&
    ok "$skill: installed for every agent, name matches its folder" || bad "$skill: installed for every agent, name matches its folder"
done
for skill in explain-d-ez explain-d-in learning-docs; do
  grep -q 'explain-standard.agentk.md' "$KIT/templates/skills/$skill/SKILL.md" &&
    ok "$skill follows the explanation standard" || bad "$skill follows the explanation standard"
done
grep -q 'Explain this at about 80% of the way to ASD-STE100' "$R/.agents/kit/explain-standard.agentk.md" &&
  ok "the explanation standard is installed with the user's words" || bad "the explanation standard is installed with the user's words"
! grep -q 'explain-standard' "$KIT/templates/skills/explain-diff/SKILL.md" &&
  ok "explain-diff keeps its own rules (for comparison)" || bad "explain-diff keeps its own rules (for comparison)"
SKEL="$KIT/templates/skills/explain-d-in/page-skeleton.html"
! grep -qi '<script[^>]*src=' "$SKEL" && grep -q 'white-space: pre' "$SKEL" &&
  ok "explain-d-in skeleton: no outside scripts, code keeps its newlines" || bad "explain-d-in skeleton: no outside scripts, code keeps its newlines"
for python in python3 python; do command -v "$python" >/dev/null 2>&1 && break; done
awk '/id="quiz-data"/ { on = 1; next } on && /<\/script>/ { exit } on { print }' "$SKEL" |
  "$python" -c 'import json, sys; d = json.load(sys.stdin); assert {"level", "q", "options", "answer", "why"} <= set(d[0])' 2>/dev/null &&
  ok "explain-d-in skeleton: the quiz block is valid JSON" || bad "explain-d-in skeleton: the quiz block is valid JSON"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
