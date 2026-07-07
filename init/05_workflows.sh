#!/bin/bash

set -e

echo "→ Writing workflows..."

# -p = create parent directories if they don't exist; no error if already there.
mkdir -p .github/workflows

# written will accumulate paths of files we actually changed,
# so we can stage only those with git add at the end.
written=()

# Full version tag (e.g. "0.9.8") or "master" when running from source.
REPOKIT_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2> /dev/null || echo "master")
# Reusable workflows are pinned to major.minor (e.g. "0.9") so patch bumps
# don't require regenerating client workflows. Falls back to "master".
if [[ "$REPOKIT_VERSION" == "master" ]]; then
  REPOKIT_VERSION_REF="master"
else
  # cut -d. -f1,2: split on ".", take fields 1 and 2 → "0.9.8" → "0.9".
  REPOKIT_VERSION_REF=$(echo "$REPOKIT_VERSION" | cut -d. -f1,2)
fi

# Glob expands to every .yml file in the wrappers directory.
for template in "$SCRIPT_DIR/languages/$LANGUAGE/wrappers/"*.yml; do
  # basename strips the directory prefix, leaving just the filename.
  name=$(basename "$template")
  dest=".github/workflows/$name"

  # Render the template: replace all {{REPO}} and {{VERSION}} placeholders.
  # s/old/new/g = substitute, g = all occurrences (not just the first).
  # Two substitutions chained with ; in a single sed call.
  new_content=$(sed "s/{{REPO}}/$REPO/g;s/{{VERSION}}/$REPOKIT_VERSION_REF/g" "$template")

  if [[ -f "$dest" && "${REPOKIT_FORCE:-false}" == false ]]; then
    # ${REPOKIT_FORCE:-false}: if REPOKIT_FORCE is unset, default to "false".
    if [[ "$new_content" == "$(cat "$dest")" ]]; then
      continue # file already matches rendered template — nothing to do
    fi
    # Check who last committed this file. If it wasn't repokit, don't overwrite
    # (the user may have customized it).
    # --format="%ae" = author email only; -1 = last commit; -- = file path follows.
    last_author=$(git log --format="%ae" -1 -- "$dest" 2> /dev/null)
    if [[ "$last_author" != "repokit@djachenko" ]]; then
      echo "  skip $name (not repokit-managed) — rerun with --force-workflows to overwrite"
      continue
    fi
  fi

  echo "$new_content" > "$dest"
  # += appends to the array.
  written+=("$dest")
done

# ${#written[@]}: # = length operator, @ = all elements → number of elements in array.
if [[ ${#written[@]} -gt 0 ]]; then
  # "${written[@]}" expands each array element as a separate argument to git add.
  git add "${written[@]}"

  # --cached = staged changes only; --quiet = no output, exit 1 if diff exists.
  if ! git diff --cached --quiet; then
    repokit_commit "update ci workflows"
  fi
fi
