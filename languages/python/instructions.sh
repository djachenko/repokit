#!/bin/bash

echo ""
echo "┌─ Next steps ────────────────────────────────────────────────────────────┐"
echo "│                                                                          │"
echo "│  1. Add APP_ID and APP_PRIVATE_KEY secrets to the repo:                  │"
echo "│     https://github.com/$OWNER/$REPO/settings/secrets/actions"
echo "│     (GitHub App credentials for push/release auth)                      │"
echo "│                                                                          │"

if [[ -z "$GITHUB_APP_ID" ]]; then
  echo "│  ! GITHUB_APP_ID not set — bypass actors were NOT added to the ruleset.  │"
  echo "│    Add GITHUB_APP_ID=<id> to ~/.repokit and re-run, or add manually:    │"
  echo "│    https://github.com/$OWNER/$REPO/settings/rules"
  echo "│                                                                          │"
fi

echo "│  2. Add Trusted Publisher on PyPI:                                      │"
echo "│     https://pypi.org/manage/account/publishing/                         │"
echo "│     owner: $OWNER   repo: $REPO   workflow: release.yml"
echo "│                                                                          │"
echo "│  3. Add Trusted Publisher on TestPyPI:                                  │"
echo "│     https://test.pypi.org/manage/account/publishing/                    │"
echo "│     owner: $OWNER   repo: $REPO   workflow: integration.yml"
echo "│                                                                          │"
echo "└──────────────────────────────────────────────────────────────────────────┘"
