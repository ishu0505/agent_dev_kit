---
name: portfolio-update
description: Offer to update an existing portfolio entry from verified project changes. Use during wrap-up for an opted-in repository or when the user requests a portfolio update.
---

# Portfolio update

1. In the source repo, read `git config --local --get agentkit.portfolioRepo`
   and `git config --local --get agentkit.portfolioProject`. Both must have
   a value. The first is the absolute path to a separate local site
   checkout. The second is the portfolio entry's ID. If either setting is
   missing, end quietly during wrap-up. On an explicit request, explain
   which setting is missing.
2. Use the task's diff and verified results to identify changes worth
   showing to portfolio readers. For a manual run without an active task,
   use the release or commit range the user identifies. Use public release
   facts or details the user has cleared for publication. End the check
   if nothing public-facing changed.
3. Read the site repo's instructions. Find the project by its ID and
   follow its links to any write-up or guide in that checkout. If the ID
   is missing or ambiguous, report it before editing. Compare the
   existing copy with the source evidence.
4. Show the proposed changes and destination files in one question.
   Wait for the user's yes before changing the site. An explicit request
   naming the site and content to update counts as approval for that scope.
5. Edit the approved content, preserve unrelated work and run the site's
   content or build checks. Report what changed. Get separate authorization
   before committing, pushing, opening a PR or deploying the site.
