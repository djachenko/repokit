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
