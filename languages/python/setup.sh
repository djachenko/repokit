#!/bin/bash

set -e

TPL="$SCRIPT_DIR/languages/python/pyproject.toml"

if [[ -f "pyproject.toml" && "${REPOKIT_FORCE:-false}" == false ]]; then
  echo "→ Writing pyproject.toml... skip (already exists, use --force-pyproject to overwrite)"
else
  echo "→ Writing pyproject.toml..."
  sed "s/{{REPO}}/$REPO/g; s/{{OWNER}}/$OWNER/g" "$TPL" > pyproject.toml
  git add pyproject.toml
  repokit_commit "add pyproject.toml"
fi
