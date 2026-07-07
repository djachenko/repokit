#!/bin/bash

set -e

echo "→ Applying ruleset..."

# Prints "<job_id>\t<uses>" per job in a wrapper workflow file (uses empty for plain jobs).
parse_jobs() {
  local file="$1"
  awk '
    /^jobs:/ { in_jobs=1; next }
    in_jobs && /^  [A-Za-z0-9_-]+:$/ {
      if (job != "") print job "\t" uses
      job=$0; sub(/^  /, "", job); sub(/:$/, "", job)
      uses=""
      next
    }
    in_jobs && /^    uses:/ {
      u=$0; sub(/^    uses: */, "", u)
      uses=u
    }
    END { if (job != "") print job "\t" uses }
  ' "$file"
}

# Prints the id of the job nothing else in the file depends on (the terminal job of the chain).
resolve_terminal_job() {
  local file="$1"
  awk '
    /^jobs:/ { in_jobs=1; next }
    in_jobs && /^  [A-Za-z0-9_-]+:$/ {
      job=$0; sub(/^  /, "", job); sub(/:$/, "", job)
      jobs[job]=1
      next
    }
    in_jobs && /^    needs:/ {
      n=$0; sub(/^    needs: */, "", n)
      gsub(/[\[\]]/, "", n)
      split(n, arr, ",")
      for (i in arr) {
        gsub(/^ +| +$/, "", arr[i])
        if (arr[i] != "") needed[arr[i]]=1
      }
    }
    END {
      for (j in jobs) if (!(j in needed)) print j
    }
  ' "$file"
}

# Required checks must be satisfiable on a PR head commit, so only wrapper workflows
# that actually run there (pull_request or push-on-any-branch) count — release.yml,
# which only fires on push to master, never can.
required_checks=()

for wf in tests.yml integration.yml; do
  file=".github/workflows/$wf"
  [[ -f "$file" ]] || continue

  while IFS=$'\t' read -r job uses; do
    [[ -z "$job" ]] && continue

    if [[ -n "$uses" ]]; then
      reusable_name=$(basename "${uses%@*}")
      reusable_file="$SCRIPT_DIR/.github/workflows/$reusable_name"

      if [[ -f "$reusable_file" ]]; then
        terminal=$(resolve_terminal_job "$reusable_file" | head -1)
        required_checks+=("$job / $terminal")
      else
        echo "  warn: reusable workflow $reusable_name not found in repokit, falling back to '$job' as check context"
        required_checks+=("$job")
      fi
    else
      required_checks+=("$job")
    fi
  done < <(parse_jobs "$file")
done

if [[ ${#required_checks[@]} -eq 0 ]]; then
  echo "  warn: could not derive any required status checks from .github/workflows — leaving required_status_checks empty"
fi

contexts_json=""
for ctx in "${required_checks[@]}"; do
  contexts_json+="{ \"context\": \"$ctx\" },"
done
contexts_json="${contexts_json%,}"

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
        "required_status_checks": [ $contexts_json ]
      }
    }
  ]
}
EOF
