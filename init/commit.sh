#!/bin/bash

set -e

echo "→ Committing..."

git add .
git commit -m "chore: initial setup"
git push -u origin master
