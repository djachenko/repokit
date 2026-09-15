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
  if [[ ! -f "$file" ]]; then
    cp "$TPL/$file" "$file"
    # Only the scripts are executable; the manifest is sourced and the plist
    # is data. Padding with spaces makes the substring test whole-word.
    if [[ " $DOTFILES_SCRIPTS " == *" $file "* ]]; then
      chmod +x "$file"
    fi
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
  repokit_commit "add dotfiles scripts"
fi
