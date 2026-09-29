#!/bin/bash

set -e

echo "→ Checking tools..."

# Each check prints its own line as it passes, so a failure shows exactly where
# the chain stopped instead of one summary line followed by silence.
#
# "name|where to get it" — bash 3.2 has no associative arrays, so the pair
# travels as one string and is split on the pipe below.
for tool in \
  "git|https://git-scm.com" \
  "gh|https://cli.github.com"; do
  # ${var%%|*} drops everything from the first pipe on; ${var#*|} drops
  # everything up to and including it.
  name="${tool%%|*}"
  install_url="${tool#*|}"

  # `command -v` prints the path to an executable and exits 0 if found, 1 if
  # not. `&> /dev/null` suppresses the path — only the exit code matters.
  if ! command -v "$name" &> /dev/null; then
    echo "  ✗ $name not found. Install: $install_url"
    exit 1
  fi

  echo "  ✓ $name"
done

# Not a presence check, so it stays out of the loop: gh can be installed and
# still have no token. `gh auth status` exits non-zero when there is none.
if ! gh auth status &> /dev/null; then
  echo "  ✗ gh not authenticated. Run: gh auth login"
  exit 1
fi

echo "  ✓ gh auth"

# repokore is not checked here: the orchestrator sources scripts/repokore-env
# before this step, and already calls the binary to read .repokit.
