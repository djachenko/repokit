#!/bin/bash

set -e

echo "→ Committing..."

git add .
repokit_commit "initial setup"
run_quiet git push -u origin master
