#!/bin/bash

set -e

echo "→ Writing pyproject.toml..."

if [[ -f "pyproject.toml" ]]; then
  echo "  skip pyproject.toml (already exists)"
else
  sed "s/{{REPO}}/$REPO/g; s/{{OWNER}}/$OWNER/g" \
    "$SCRIPT_DIR/templates/pyproject.toml" > pyproject.toml
fi
