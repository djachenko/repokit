#!/bin/bash

set -e

if [[ ! -f cog.toml ]]; then
  cp "$SCRIPT_DIR/languages/bash/cog.toml" cog.toml
  git add cog.toml
  repokit_commit "add cog.toml"
fi
