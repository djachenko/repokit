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
    sed \
      -e "s/{{REPO}}/$REPO/g" \
      -e "s/{{APP_SLUG}}/${APP_SLUG:-github-actions}/g" \
      -e "s/{{APP_ACTOR_ID}}/${APP_ACTOR_ID:-41898282}/g" \
      "$tpl" > "$dest"
  fi
done
