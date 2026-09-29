#!/bin/bash

set -e

echo "→ Applying ruleset..."

# ── Collect required check contexts ──────────────────────────────────────────
#
# Only workflows that run on pull_request (or on every push) can satisfy a
# required status check on a PR commit. release.yml only fires on push to
# master, so it can never be a required check — it is not listed here.
#
# repokore parses the wrappers, follows each `uses:` into repokit's own
# reusable workflows to find the terminal job, and emits the whole
# required_status_checks array as JSON. Missing wrapper files are skipped.
contexts_json=$("$REPOKORE" ruleset-checks \
  --reusable "$SCRIPT_DIR/.github/workflows" \
  .github/workflows/tests.yml \
  .github/workflows/integration.yml)

# Read app_id from .repokit (user sets this after creating their GitHub App).
# If absent, bypass_actors is empty — direct master pushes will be blocked by
# the ruleset until the App is configured and repokit is re-run.
app_id=$("$REPOKORE" config get app_id)

if [[ -n "$app_id" ]]; then
  bypass_actors_json='[{"actor_id": '"$app_id"', "actor_type": "Integration", "bypass_mode": "always"}]'
else
  bypass_actors_json='[]'
fi

# ── Apply ruleset via GitHub API ──────────────────────────────────────────────
#
# The Rulesets API has no PATCH/update endpoint that's safe to use idempotently,
# so we delete the existing one (if any) and recreate it from scratch.

RULESET_NAME="$OWNER-github-flow-ruleset"
RULESET_ID=$(gh api "repos/$OWNER/$REPO/rulesets" --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2> /dev/null)

if [[ -n "$RULESET_ID" ]]; then
  gh api "repos/$OWNER/$REPO/rulesets/$RULESET_ID" --method DELETE
fi

gh api "repos/$OWNER/$REPO/rulesets" \
  --method POST \
  --header "Content-Type: application/json" \
  --input - > /dev/null << EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "bypass_actors": $bypass_actors_json,
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "required_reviewers": [],
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": $contexts_json
      }
    }
  ]
}
EOF
