#!/bin/bash

set -e

TPL="$SCRIPT_DIR/languages/swift/templates"

echo "→ Writing Swift tooling..."

written=()

# Files repokit keeps up to date, as template → destination pairs: two plain
# lists by index, because macOS ships bash 3.2, which has no associative arrays.
templates=(swiftlint_base.yml swiftlint_tests.yml cog.toml repokit_skill.md)
destinations=(.swiftlint_base.yml Tests/.swiftlint.yml cog.toml .claude/skills/repokit.md)

# ${!templates[@]} expands to the indexes of the array: 0, 1, 2, …
for i in "${!templates[@]}"; do
  dest=${destinations[$i]}

  # Same rule as the workflows step: write only what is still repokit's and
  # out of date, and print the path if it did.
  wrote=$("$REPOKORE" sync \
    --skip-hint "delete it and re-run to take the new version" \
    "$TPL/${templates[$i]}" "$dest")

  # A gitignored path (.claude/ often is) stays written but unstaged: git add
  # refuses ignored paths, and under set -e that would end the run.
  if [[ -n "$wrote" ]] && ! git check-ignore -q "$dest"; then
    git add "$dest"
    written+=("$dest")
  fi
done

# The repo's own SwiftLint config: written once and then the repo's, never
# updated — so a plain existence check, not sync. It is what links the base
# in: without parent_config nothing reads .swiftlint_base.yml, tests included.
if [[ ! -e .swiftlint.yml ]]; then
  cp "$TPL/swiftlint.yml" .swiftlint.yml
  git add .swiftlint.yml
  written+=(.swiftlint.yml)
elif ! grep -qx 'parent_config: .swiftlint_base.yml' .swiftlint.yml; then
  # grep -x: the whole line must match, not just contain the text.
  echo "  note: .swiftlint.yml does not inherit the shared rules — add: parent_config: .swiftlint_base.yml"
fi

# The template is GitHub's Swift.gitignore, verbatim but for two uncommented
# entries. Only its patterns go in: .gitignore already exists by now — the
# orchestrator has added .repokit to it — and repokore appends just the lines
# missing from it, so comments and blank lines are filtered out first.
# repokore prints what it added; empty output means nothing to commit.
if [[ -n "$(grep -v -e '^#' -e '^$' "$TPL/gitignore" | xargs "$REPOKORE" gitignore add)" ]]; then
  git add .gitignore
  written+=(.gitignore)
fi

if [[ ${#written[@]} -gt 0 ]] && ! git diff --cached --quiet; then
  repokit_commit "sync swift tooling"
fi
