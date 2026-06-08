#!/bin/bash

set -e

echo "→ Writing workflows..."

mkdir -p .github/workflows

for tpl in "$SCRIPT_DIR/languages/$LANGUAGE/workflows/"*.yml; do
  name=$(basename "$tpl")
  dest=".github/workflows/$name"
  if [[ -f "$dest" ]]; then
    echo "  skip $name (already exists)"
  else
    sed "s/{{REPO}}/$REPO/g" "$tpl" > "$dest"
  fi
done
