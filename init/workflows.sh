#!/bin/bash

set -e

echo "→ Writing workflows..."

mkdir -p .github/workflows

written=()

for template in "$SCRIPT_DIR/languages/$LANGUAGE/wrappers/"*.yml; do
  name=$(basename "$template")
  dest=".github/workflows/$name"

  if [[ -f "$dest" && "${REPOKIT_FORCE:-false}" == false ]]; then
    last_author=$(git log --format="%ae" -1 -- "$dest" 2> /dev/null)
    if [[ "$last_author" != "repokit@djachenko" ]]; then
      echo "  skip $name (modified by user)"
      continue
    fi
  fi

  sed "s/{{REPO}}/$REPO/g" "$template" > "$dest"

  written+=("$dest")
done

if [[ ${#written[@]} -gt 0 ]]; then
  git add "${written[@]}"

  if ! git diff --cached --quiet; then
    repokit_commit "update ci workflows"
  fi
fi
