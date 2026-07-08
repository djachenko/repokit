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

needs_gitignore_update=false
for entry in 'CLAUDE.local.md' '_claude' 'logs/'; do
  if ! grep -qxF "$entry" .gitignore 2> /dev/null; then
    echo "$entry" >> .gitignore
    needs_gitignore_update=true
  fi
done
if $needs_gitignore_update; then
  git add .gitignore
  written+=(".gitignore")
fi

if [[ ${#written[@]} -gt 0 ]] && ! git diff --cached --quiet; then
  repokit_commit "add dotfiles scripts"
fi
