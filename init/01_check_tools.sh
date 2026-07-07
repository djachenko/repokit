#!/bin/bash

set -e

echo "→ Checking tools: git, gh..."

# Abort if git is not installed.
# `command -v` prints the path to an executable and exits 0 if found, 1 if not.
# `!` inverts the exit code so we enter the if-block on failure.
# `&> /dev/null` suppresses the printed path — we only care about the exit code.
if ! command -v git &> /dev/null; then
  echo "✗ git not found. Install: https://git-scm.com"
  exit 1
fi

# Abort if gh (GitHub CLI) is not installed.
if ! command -v gh &> /dev/null; then
  echo "✗ gh not found. Install: https://cli.github.com"
  exit 1
fi

# Abort if gh is installed but not authenticated.
# `gh auth status` exits non-zero when there is no valid token stored.
if ! gh auth status &> /dev/null; then
  echo "✗ gh not authenticated. Run: gh auth login"
  exit 1
fi
