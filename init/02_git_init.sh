#!/bin/bash

set -e

echo "→ Initializing git..."

# Create a new git repo in the current directory.
# `run_quiet` is a helper defined in the orchestrator: it hides command output
# unless the command fails, so the terminal stays clean on the happy path.
run_quiet git init
