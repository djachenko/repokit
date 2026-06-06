#!/bin/bash

set -e

echo "→ Writing workflows..."

mkdir -p .github/workflows

for tpl in "$SCRIPT_DIR/templates/workflows/"*.yml; do
  name=$(basename "$tpl")
  sed "s/{{REPO}}/$REPO/g" "$tpl" > ".github/workflows/$name"
done
