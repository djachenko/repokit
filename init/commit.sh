#!/bin/bash

set -e

echo "→ Committing..."

git add .
repokit_commit "initial setup"
git push -u origin master
