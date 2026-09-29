#!/bin/bash

set -e

echo "→ Writing workflows..."

# written will accumulate paths of files we actually changed,
# so we can stage only those with git add at the end.
written=()

# Full version tag (e.g. "0.9.8") or "master" when running from source. repokore
# reduces it to the major.minor ref (0.9.8 → 0.9) that client workflows pin to,
# so a patch release doesn't require regenerating them.
REPOKIT_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2> /dev/null || echo "master")

# --force-workflows overwrites wrappers the user has changed. An empty array
# expands to nothing, so the flag is simply absent otherwise.
force=()
[[ "${REPOKIT_FORCE:-false}" == true ]] && force=(--force)

# Glob expands to every .yml file in the wrappers directory.
for template in "$SCRIPT_DIR/languages/$LANGUAGE/wrappers/"*.yml; do
  # repokore renders the template and writes it only if the workflow is still
  # repokit's — last committed by repokit, no uncommitted edits — and differs.
  # It prints the path when it wrote it, so an empty result means nothing to
  # stage. Assigned rather than tested inline: set -e does not see a failure
  # inside [[ ]].
  dest=".github/workflows/$(basename "$template")"
  wrote=$("$REPOKORE" sync "${force[@]}" \
    --skip-hint "rerun with --force-workflows to overwrite" \
    --repo "$REPO" --version "$REPOKIT_VERSION" \
    "$template" "$dest")

  if [[ -n "$wrote" ]]; then
    written+=("$dest")
  fi
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
