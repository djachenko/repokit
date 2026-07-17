#!/bin/bash

set -e

echo "→ Applying ruleset..."

# ── YAML parsers ──────────────────────────────────────────────────────────────
#
# We need to know which GitHub Actions check contexts to require on PRs.
# The check context name for a reusable-workflow job is "<wrapper-job> / <reusable-job>",
# not just "<wrapper-job>" — so we parse the wrapper file to find which jobs call
# reusable workflows, then parse the reusable file to find its terminal job.

# parse_jobs <file>
# Prints one "<job_id>\t<uses>" line per job in a wrapper workflow YAML.
# For plain jobs (no `uses:`) the <uses> field is empty.
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

# resolve_terminal_job <file>
# Prints the job id that no other job in the file depends on (the last in the chain).
# GitHub reports the check context as "<caller> / <terminal>", so required_status_checks
# must use the terminal job name, not an intermediate one.
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
      gsub(/[\[\]]/, "", n)          # strip [ ] from needs: [a, b] form
      split(n, arr, ",")
      for (i in arr) {
        gsub(/^ +| +$/, "", arr[i]) # trim spaces around each name
        if (arr[i] != "") needed[arr[i]]=1
      }
    }
    END {
      for (j in jobs) if (!(j in needed)) print j
    }
  ' "$file"
}

# ── Collect required check contexts ──────────────────────────────────────────
#
# Only workflows that run on pull_request (or on every push) can satisfy a
# required status check on a PR commit.  release.yml only fires on push to
# master, so it can never be a required check — we skip it here.

required_checks=()

for wf in tests.yml integration.yml; do

  file=".github/workflows/$wf"
  [[ -f "$file" ]] || continue

  # IFS=$'\t' so read splits on the tab that parse_jobs inserts between fields.
  while IFS=$'\t' read -r job uses; do
    [[ -z "$job" ]] && continue

    if [[ -n "$uses" ]]; then
      # Strip the @ref suffix from the uses value (e.g. "owner/repo/.../file.yml@v1")
      # to get the bare filename, then look it up inside repokit's own workflows.
      reusable_name=$(basename "${uses%@*}")
      reusable_file="$SCRIPT_DIR/.github/workflows/$reusable_name"

      if [[ -f "$reusable_file" ]]; then
        terminal=$(resolve_terminal_job "$reusable_file" | head -1)
        # GitHub check context for a reusable call: "<caller-job> / <reusable-job>"
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

# Build the JSON array fragment for required_status_checks.
contexts_json=""
for ctx in "${required_checks[@]}"; do
  contexts_json+="{ \"context\": \"$ctx\" },"
done

contexts_json="${contexts_json%,}" # strip trailing comma

# Read app_id from .repokit (user sets this after creating their GitHub App).
# If absent, bypass_actors is empty — direct master pushes will be blocked by
# the ruleset until the App is configured and repokit is re-run.
app_id=$(grep '^app_id=' .repokit 2> /dev/null | cut -d= -f2)
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
        "required_status_checks": [ $contexts_json ]
      }
    }
  ]
}
EOF
