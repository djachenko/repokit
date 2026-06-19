#!/bin/bash

set -e

TPL="$SCRIPT_DIR/languages/python/pyproject.toml"

new_content=$(sed "s/{{REPO}}/$REPO/g; s/{{OWNER}}/$OWNER/g" "$TPL")

if [[ -f "pyproject.toml" && "${REPOKIT_FORCE:-false}" == false ]]; then
  if [[ "$new_content" != "$(cat pyproject.toml)" ]]; then
    echo "→ Writing pyproject.toml... skip (modified by user — use --force-pyproject to overwrite)"
  fi
else
  echo "→ Writing pyproject.toml..."
  echo "$new_content" > pyproject.toml
  git add pyproject.toml
  repokit_commit "add pyproject.toml"
fi
