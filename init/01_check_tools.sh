#!/bin/bash

set -e

echo "→ Checking requirements..."

if ! command -v git &> /dev/null; then
  echo "✗ git not found. Install: https://git-scm.com"
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "✗ gh not found. Install: https://cli.github.com"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  echo "✗ gh not authenticated. Run: gh auth login"
  exit 1
fi
