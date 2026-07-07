#!/bin/bash

set -e

echo "→ Writing workflows..."

mkdir -p .github/workflows

written=()

REPOKIT_FULL=$(cat "$SCRIPT_DIR/VERSION" 2> /dev/null || echo "master")
if [[ "$REPOKIT_FULL" == "master" ]]; then
  REPOKIT_REF="master"
else
  REPOKIT_REF=$(echo "$REPOKIT_FULL" | cut -d. -f1,2)
fi

for template in "$SCRIPT_DIR/languages/$LANGUAGE/wrappers/"*.yml; do
  name=$(basename "$template")
  dest=".github/workflows/$name"

  new_content=$(sed "s/{{REPO}}/$REPO/g;s/{{VERSION}}/$REPOKIT_REF/g" "$template")

  if [[ -f "$dest" && "${REPOKIT_FORCE:-false}" == false ]]; then
    if [[ "$new_content" == "$(cat "$dest")" ]]; then
      continue
    fi
    last_author=$(git log --format="%ae" -1 -- "$dest" 2> /dev/null)
    if [[ "$last_author" != "repokit@djachenko" ]]; then
      echo "  skip $name (not repokit-managed) — rerun with --force-workflows to overwrite"
      continue
    fi
  fi

  echo "$new_content" > "$dest"
  written+=("$dest")
done

if [[ ${#written[@]} -gt 0 ]]; then
  git add "${written[@]}"

  if ! git diff --cached --quiet; then
    repokit_commit "update ci workflows"
  fi
fi
