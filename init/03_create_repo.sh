#!/bin/bash

set -e

echo "→ Creating repository $OWNER/$REPO..."

run_quiet gh repo create "$OWNER/$REPO" --$VISIBILITY

# Enable auto-merge so that a PR with all checks green can be merged automatically
# without a second click — useful once branch protection is in place.
gh api "repos/$OWNER/$REPO" --method PATCH -f allow_auto_merge=true > /dev/null

# SSH remote so local git operations don't prompt for credentials.
# HTTPS would require a token or credential helper; SSH key is already set up.
run_quiet git remote add origin "git@github.com:$OWNER/$REPO.git"
