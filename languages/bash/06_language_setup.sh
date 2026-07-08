#!/bin/bash

set -e

# cog.toml configures cocogitto — a conventional-commit-aware changelog and
# release tool for bash projects (equivalent of python-semantic-release).
# Only copy if the file doesn't already exist (don't overwrite user edits).
if [[ ! -f cog.toml ]]; then
  cp "$SCRIPT_DIR/languages/bash/cog.toml" cog.toml
  git add cog.toml
  repokit_commit "add cog.toml"
fi
