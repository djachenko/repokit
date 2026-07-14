#!/bin/bash

if git log "origin/$BASE_BRANCH..$BRANCH" --oneline 2> /dev/null | grep -q .; then
  echo "→ Pushing $BRANCH..."
  if $BRANCH_ON_REMOTE; then
    echo "  force-pushing (rebased onto origin/$BASE_BRANCH)..."
    if ! run_quiet git push --force-with-lease -u origin "$BRANCH"; then
      echo "Error: could not push $BRANCH — origin has changes repokit didn't expect (pushed manually, or changed since the last fetch)."
      echo "Resolve manually, e.g.: git push --force origin $BRANCH"
      exit 1
    fi
  elif ! run_quiet git push -u origin "$BRANCH"; then
    echo "Error: could not push $BRANCH."
    exit 1
  fi
  gh pr create \
    --title "chore: [repokit] setup" \
    --body "Automated repository setup by repokit." \
    --base "$BASE_BRANCH" 2> /dev/null || true

  bash "$SCRIPT_DIR/languages/$LANGUAGE/instructions.sh"

  echo ""
  echo "✓ Done: https://github.com/$OWNER/$REPO"
else
  echo ""
  echo "✓ Already up to date"
fi

# -i.bak works on both BSD (macOS) and GNU sed; '' alone breaks on Linux.
sed -i.bak '/^base_branch=/d' .repokit && rm -f .repokit.bak
