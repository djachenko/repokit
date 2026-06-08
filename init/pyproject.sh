#!/bin/bash

set -e

TPL="$SCRIPT_DIR/templates/$TEMPLATE/pyproject.toml"

if [[ ! -f "$TPL" ]]; then
  echo "→ Skipping pyproject.toml (not in template '$TEMPLATE')"
elif [[ -f "pyproject.toml" ]]; then
  echo "→ Writing pyproject.toml..."
  echo "  skip pyproject.toml (already exists)"
else
  echo "→ Writing pyproject.toml..."
  sed "s/{{REPO}}/$REPO/g; s/{{OWNER}}/$OWNER/g" "$TPL" > pyproject.toml
fi
