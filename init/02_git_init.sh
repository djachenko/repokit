#!/bin/bash

set -e

echo "→ Initializing git..."

# Create a new git repo in the current directory.
# `run_quiet` is a helper defined in the orchestrator: it hides command output
# unless the command fails, so the terminal stays clean on the happy path.
# -b master sets the initial branch name explicitly; without it, the branch name
# depends on the user's init.defaultBranch setting (often "main" on modern systems).
run_quiet git init -b master
