#!/bin/bash

set -e

echo "→ Applying ruleset..."

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
  "bypass_actors": [
    { "actor_id": 2991967, "actor_type": "Integration", "bypass_mode": "always" }
  ],
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
        "required_status_checks": [
          { "context": "integration / integration" },
          { "context": "integration / publish" },
          { "context": "tests / test" }
        ]
      }
    }
  ]
}
EOF
