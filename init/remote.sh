#!/bin/bash

set -e

echo "→ Creating repository $OWNER/$REPO..."
gh repo create "$OWNER/$REPO" --public
git remote add origin "git@github.com:$OWNER/$REPO.git"
