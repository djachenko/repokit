#!/bin/bash

set -e

echo "→ Creating repository $OWNER/$REPO..."
gh repo create "$OWNER/$REPO" --public
gh api "repos/$OWNER/$REPO" --method PATCH -f allow_auto_merge=true > /dev/null
git remote add origin "git@github.com:$OWNER/$REPO.git"
