#!/bin/bash

set -e

echo "→ Creating repository $OWNER/$REPO..."

run_quiet gh repo create "$OWNER/$REPO" --"$VISIBILITY"

# SSH remote so local git operations don't prompt for credentials.
# HTTPS would require a token or credential helper; SSH key is already set up.
run_quiet git remote add origin "git@github.com:$OWNER/$REPO.git"
