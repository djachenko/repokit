#!/bin/bash

set -e

echo "→ Writing workflows..."

mkdir -p .github/workflows

written=()
for template in "$SCRIPT_DIR/languages/$LANGUAGE/wrappers/"*.yml; do
  name=$(basename "$template")
  dest=".github/workflows/$name"

  if [[ -f "$dest" && "${REPOKIT_FORCE:-false}" == false ]]; then
    echo "  skip $name (already exists)"
  else
    sed "s/{{REPO}}/$REPO/g" "$template" > "$dest"
    written+=("$dest")
  fi
done

if [[ ${#written[@]} -gt 0 ]]; then
  git add "${written[@]}"
  repokit_commit "add ci workflows"
fi
