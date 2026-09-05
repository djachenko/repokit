#!/bin/bash

set -e

TPL="$SCRIPT_DIR/languages/dotfiles/templates"

echo "→ Writing dotfiles scripts..."

written=()

for script in adopt install watch commit uninstall restart; do
  if [[ ! -f "$script" ]]; then
    cp "$TPL/$script" "$script"
    chmod +x "$script"
    git add "$script"
    written+=("$script")
  fi
done

# repokore appends only the entries that are missing and prints them, so an
# empty result means .gitignore already listed everything and needs no commit.
if [[ -n "$("$REPOKORE" gitignore add 'CLAUDE.local.md' '_claude' 'logs/')" ]]; then
  git add .gitignore
  written+=(".gitignore")
fi

if [[ ${#written[@]} -gt 0 ]] && ! git diff --cached --quiet; then
  repokit_commit "add dotfiles scripts"
fi
