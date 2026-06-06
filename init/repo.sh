#!/bin/bash

set -e

echo "→ Creating repository $OWNER/$REPO..."
gh repo create "$OWNER/$REPO" --public

echo "→ Initializing git..."
git init
git remote add origin "git@github.com:$OWNER/$REPO.git"
