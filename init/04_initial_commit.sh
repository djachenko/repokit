#!/bin/bash

set -e

echo "→ Committing..."

run_quiet git commit --allow-empty -m "chore: [repokit] initial setup" --author="$REPOKIT_AUTHOR"

# -u sets the upstream so future `git push` / `git pull` work without arguments.
# HEAD instead of a hardcoded branch name so this works regardless of init.defaultBranch.
run_quiet git push -u origin HEAD
