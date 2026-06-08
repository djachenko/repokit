#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: init_python.sh"
  echo ""
  echo "Initializes a new Python GitHub repository in the current directory."
  echo ""
  echo "  1. Create a folder:  mkdir my-repo"
  echo "  2. Enter it:         cd my-repo"
  echo "  3. Run:              init_python.sh"
  echo ""
  echo "Repo name is taken from the current directory name."
  echo "GitHub owner is taken from 'gh auth'."
  echo ""
  echo "Requirements:"
  echo "  git  — https://git-scm.com"
  echo "  gh   — https://cli.github.com (must be authenticated)"
  echo ""
  echo "First-time setup: run install.sh to add init_python.sh to PATH"
  exit 0
fi

export SCRIPT_DIR
export REPO
REPO=$(basename "$PWD")

bash "$SCRIPT_DIR/init/preflight.sh"

export OWNER
OWNER=$(gh api user --jq '.login')

HAS_GIT=false
git rev-parse --git-dir &>/dev/null && HAS_GIT=true

HAS_REMOTE=false
gh repo view "$OWNER/$REPO" &>/dev/null && HAS_REMOTE=true

if [[ "$HAS_GIT" == false && "$HAS_REMOTE" == true ]]; then
  echo "Error: GitHub repo '$OWNER/$REPO' already exists but no local git. Clone it first."
  exit 1
fi

echo "Init repo '$OWNER/$REPO' in $(pwd)? [y/N]"
read -r answer
[[ "$answer" == "y" ]] || exit 0

if [[ "$HAS_GIT" == false ]]; then
  bash "$SCRIPT_DIR/init/git_init.sh"
fi

if [[ "$HAS_REMOTE" == false ]]; then
  bash "$SCRIPT_DIR/init/remote.sh"
  if [[ "$HAS_GIT" == false ]]; then
    bash "$SCRIPT_DIR/init/commit.sh"
  else
    echo "→ Pushing existing history..."
    git push -u origin master
  fi
fi

bash "$SCRIPT_DIR/init/workflows.sh"
bash "$SCRIPT_DIR/init/pyproject.sh"
bash "$SCRIPT_DIR/init/ruleset.sh"
bash "$SCRIPT_DIR/init/instructions.sh"

echo ""
echo "✓ Done: https://github.com/$OWNER/$REPO"
