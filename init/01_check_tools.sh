#!/bin/bash

set -e

echo "→ Checking tools: git, gh, repokore..."

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

# repokore reads and writes .repokit and renders every template, so nothing
# downstream works without it. Checked once here rather than guarded at each
# call site: a partial run that silently skips steps is worse than not starting.
# -x = exists and is executable.
if [[ ! -x "$REPOKORE" ]]; then
  echo "✗ repokore not found at $REPOKORE"
  echo "  Reinstall: curl -fsSL https://raw.githubusercontent.com/djachenko/repokit/master/install.sh | bash"
  exit 1
fi
