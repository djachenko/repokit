#!/bin/bash

set -e

TPL="$SCRIPT_DIR/languages/dotfiles/templates"

echo "→ Writing dotfiles scripts..."

written=()

# The manifest is the one list of tooling files, shared with the install script
# that ends up in the user's repo. read -ra splits its space-separated value.
# shellcheck source=templates/manifest
source "$TPL/manifest"
read -ra tooling <<< "$DOTFILES_TOOLING"

for file in "${tooling[@]}"; do
  # Same rule as the workflows step, in repokore: write only what is still
  # repokit's and out of date, and print the path if it did. A new file takes
  # its template's permissions, so scripts arrive executable.
  # {{REPOKORE}} is the absolute path of this install's binary: the scripts
  # run from launchd, which has neither repokit on PATH nor XDG_DATA_HOME.
  wrote=$("$REPOKORE" sync \
    --skip-hint "delete it and re-run to take the new version" \
    --set "REPOKORE=$REPOKORE" \
    "$TPL/$file" "$file")

  if [[ -n "$wrote" ]]; then
    git add "$file"
    written+=("$file")
  fi
done

# The entries come from the gitignore template, one per line; xargs passes them
# as arguments. repokore appends only the missing ones and prints them, so an
# empty result means .gitignore already listed everything and needs no commit.
if [[ -n "$(xargs "$REPOKORE" gitignore add < "$TPL/gitignore")" ]]; then
  git add .gitignore
  written+=(".gitignore")
fi

if [[ ${#written[@]} -gt 0 ]] && ! git diff --cached --quiet; then
  repokit_commit "sync dotfiles scripts"
fi
