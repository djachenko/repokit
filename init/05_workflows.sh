#!/bin/bash

set -e

echo "→ Writing workflows..."

mkdir -p .github/workflows

written=()

# Full version tag (e.g. "0.9.8") or "master" when running from source.
REPOKIT_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2> /dev/null || echo "master")
# Reusable workflows are pinned to major.minor (e.g. "0.9") so patch bumps
# don't require regenerating client workflows. Falls back to "master".
if [[ "$REPOKIT_VERSION" == "master" ]]; then
  REPOKIT_VERSION_REF="master"
else
  REPOKIT_VERSION_REF=$(echo "$REPOKIT_VERSION" | cut -d. -f1,2)
fi

for template in "$SCRIPT_DIR/languages/$LANGUAGE/wrappers/"*.yml; do
  name=$(basename "$template")
  dest=".github/workflows/$name"

  new_content=$(sed "s/{{REPO}}/$REPO/g;s/{{VERSION}}/$REPOKIT_VERSION_REF/g" "$template")

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
