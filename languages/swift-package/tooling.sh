#!/bin/bash

# Sourced, never run: the SwiftLint, cog and gitignore steps shared by the
# swift-package and swift-app language setups. Each setup decides what goes
# where; these only write and stage it, collecting the staged paths in written.

written=()

# Syncs each template in the templates array to the path at the same index in
# destinations: two plain lists by index, because macOS ships bash 3.2, which
# has no associative arrays.
sync_tooling() {
  local i dest wrote

  # ${!templates[@]} expands to the indexes of the array: 0, 1, 2, …
  for i in "${!templates[@]}"; do
    dest=${destinations[$i]}

    # Same rule as the workflows step: write only what is still repokit's and
    # out of date, and print the path if it did.
    wrote=$("$REPOKORE" sync \
      --skip-hint "delete it and re-run to take the new version" \
      "${templates[$i]}" "$dest")

    # A gitignored path (.claude/ often is) stays written but unstaged: git add
    # refuses ignored paths, and under set -e that would end the run.
    if [[ -n "$wrote" ]] && ! git check-ignore -q "$dest"; then
      git add "$dest"
      written+=("$dest")
    fi
  done
}

# The repo's own SwiftLint config at $1, from template $2: written once and
# then the repo's, never updated — so a plain existence check, not sync. It is
# what links the base in: without parent_config nothing reads
# .swiftlint_base.yml, tests included.
write_lint_config() {
  local config=$1/.swiftlint.yml

  if [[ ! -e $config ]]; then
    cp "$2" "$config"
    git add "$config"
    written+=("$config")
  elif ! grep -qx 'parent_config: .swiftlint_base.yml' "$config"; then
    # grep -x: the whole line must match, not just contain the text.
    echo "  note: $config does not inherit the shared rules — add: parent_config: .swiftlint_base.yml"
  fi
}

# Appends the gitignore patterns read from stdin. .gitignore already exists by
# now — the orchestrator has added .repokit to it — and repokore appends just
# the lines missing from it. It prints what it added; empty means nothing to
# commit.
add_gitignore() {
  if [[ -n "$(xargs "$REPOKORE" gitignore add)" ]]; then
    git add .gitignore
    written+=(.gitignore)
  fi
}

# The gitignore template is GitHub's Swift.gitignore: only its patterns go in,
# comments and blank lines are filtered out.
gitignore_patterns() {
  grep -v -e '^#' -e '^$' "$1"
}

commit_tooling() {
  if [[ ${#written[@]} -gt 0 ]] && ! git diff --cached --quiet; then
    repokit_commit "sync swift tooling"
  fi
}
