#!/bin/bash

BRANCH="chore/repokit-setup"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ "$CURRENT_BRANCH" == "$BRANCH" ]]; then
  BASE_BRANCH=$("$REPOKORE" config get base_branch)
  BASE_BRANCH=${BASE_BRANCH:-master}
else
  BASE_BRANCH="$CURRENT_BRANCH"
fi

# The base is where the setup PR will be opened, so it has to exist on origin.
# --exit-code returns 2 only for a missing ref; network errors fall through to
# the fetch below, which reports them as they are.
status=0
git ls-remote --exit-code --heads origin "$BASE_BRANCH" &> /dev/null || status=$?

if [[ $status -eq 2 ]]; then
  echo "Error: branch $BASE_BRANCH is not on origin."
  echo "  repokit opens the setup PR into the branch you run it from — here $BASE_BRANCH."
  echo "  Switch to the branch the PR should target (usually master) and re-run,"
  echo "  or push $BASE_BRANCH if the PR really belongs there."
  exit 1
fi

run_quiet git fetch origin "$BASE_BRANCH"

BRANCH_ON_REMOTE=false

if git ls-remote --exit-code --heads origin "$BRANCH" &> /dev/null; then
  BRANCH_ON_REMOTE=true

  run_quiet git fetch origin "$BRANCH"
fi

LOCAL_BRANCH_EXISTS=false
git rev-parse --verify "$BRANCH" &> /dev/null && LOCAL_BRANCH_EXISTS=true

if $LOCAL_BRANCH_EXISTS || $BRANCH_ON_REMOTE; then
  echo "→ Updating branch $BRANCH from origin/$BASE_BRANCH..."

  if $LOCAL_BRANCH_EXISTS; then
    run_quiet git checkout "$BRANCH"
  else
    run_quiet git checkout -B "$BRANCH" "origin/$BRANCH"
  fi

  if ! run_quiet git rebase "origin/$BASE_BRANCH"; then
    git rebase --abort 2> /dev/null || true

    echo "Error: could not rebase $BRANCH onto origin/$BASE_BRANCH — resolve manually."
    exit 1
  fi
else
  echo "→ Creating branch $BRANCH from origin/$BASE_BRANCH..."

  run_quiet git checkout -B "$BRANCH" "origin/$BASE_BRANCH"
fi
