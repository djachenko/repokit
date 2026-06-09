#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && SHELL_RC="$HOME/.bashrc"

LINE="export PATH=\"$SCRIPT_DIR:\$PATH\""

if grep -qF "$SCRIPT_DIR" "$SHELL_RC" 2> /dev/null; then
  echo "Already in PATH ($SHELL_RC)"
else
  echo "$LINE" >> "$SHELL_RC"
  echo "Added to $SHELL_RC. Restart shell or: source $SHELL_RC"
fi

git config --global core.hooksPath "$SCRIPT_DIR/hooks"
echo "Git hooks configured globally ($SCRIPT_DIR/hooks)"

OWNER_EMAIL=$(gh api user --jq '.email // empty' 2> /dev/null)
if [[ -z "$OWNER_EMAIL" ]]; then
  OWNER_EMAIL=$(git config --global user.email)
fi
if [[ -n "$OWNER_EMAIL" ]]; then
  git config --global repokit.ownerEmail "$OWNER_EMAIL"
  echo "Owner email set: $OWNER_EMAIL"
fi
