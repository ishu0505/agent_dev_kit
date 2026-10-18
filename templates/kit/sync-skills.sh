#!/bin/sh
# Make .claude/skills show the skills kept in .agents/skills.
# SKILLS_LINK="symlink" (default): a link, so there is only one copy.
# SKILLS_LINK="copy": a real copy, for clones where symlinks do not work
# (Windows without Developer Mode). Run again after editing a skill.
set -eu
cd "$(git rev-parse --show-toplevel)"
SKILLS_LINK="symlink"
[ -f .agents/agent-kit.conf ] && . ./.agents/agent-kit.conf
mkdir -p .claude
rm -rf .claude/skills
if [ "$SKILLS_LINK" = "symlink" ]; then
  ln -s ../.agents/skills .claude/skills 2>/dev/null || true
  if [ -L .claude/skills ]; then echo "linked .claude/skills -> ../.agents/skills"; exit 0; fi
  # Git Bash on Windows copies instead of linking: switch this repo to copy mode.
  rm -rf .claude/skills
  sed 's/^SKILLS_LINK=.*/SKILLS_LINK="copy"/' .agents/agent-kit.conf > .agents/agent-kit.conf.tmp &&
    mv .agents/agent-kit.conf.tmp .agents/agent-kit.conf
  grep -q '^SKILLS_LINK=' .agents/agent-kit.conf || printf '\nSKILLS_LINK="copy"\n' >> .agents/agent-kit.conf
  echo "symlinks do not work here: set SKILLS_LINK=\"copy\" in .agents/agent-kit.conf"
fi
cp -R .agents/skills .claude/skills
echo "copied .agents/skills -> .claude/skills"
