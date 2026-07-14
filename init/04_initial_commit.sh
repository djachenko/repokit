#!/bin/bash

set -e

echo "→ Committing..."

# git add . is intentional here: this is the very first commit of a brand-new
# repo, so there are no pre-existing tracked files to accidentally include.
# Subsequent repokit commits always use named files.
git add .
run_quiet git commit --allow-empty -m "chore: [repokit] initial setup" --author="$REPOKIT_AUTHOR"

# -u sets the upstream so future `git push` / `git pull` work without arguments.
# HEAD instead of a hardcoded branch name so this works regardless of init.defaultBranch.
run_quiet git push -u origin HEAD
