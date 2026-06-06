#!/bin/bash

set -e

echo "→ Writing pyproject.toml..."

sed "s/{{REPO}}/$REPO/g; s/{{OWNER}}/$OWNER/g" \
  "$SCRIPT_DIR/templates/pyproject.toml" > pyproject.toml
