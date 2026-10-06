#!/usr/bin/env bats

# init/ steps, run through the orchestrator's own run_step — sourced into the
# caller, with language overrides — against a bare origin and the gh shim.

load helpers

setup() {
  setup_repokit_env
  setup_repo
}

# Steps run in sequence share one shell, as in the orchestrator: 08 reads the
# BRANCH and BASE_BRANCH that 05 set.
steps() {
  local step
  for step in "$@"; do
    run_step "$step"
  done
}

# The JSON body of the POST that creates the ruleset, from the gh log.
ruleset_body() {
  awk '/^=== gh api .*--method POST/ { on = 1; next } /^=== / { on = 0 } on' "$GH_CALLS_LOG"
}

# ── 01_check_tools ──────────────────────────────────────────────────────────

@test "01 reports each check as it passes" {
  run steps 01_check_tools.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ git"*"✓ gh"*"✓ gh auth"* ]]
}

# PATH narrowed inside the call, not as `PATH=… run`: run itself needs the
# tools a narrowed PATH takes away.
with_path() {
  local PATH="$1"
  shift
  "$@"
}

# tests/bin holds the gh shim and no git.
@test "01 stops when git is missing" {
  run with_path "$BATS_TEST_DIRNAME/bin" steps 01_check_tools.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ git not found"* ]]
}

@test "01 stops when gh is missing" {
  mkdir "$BATS_TEST_TMPDIR/no-gh"
  ln -s "$(command -v git)" "$BATS_TEST_TMPDIR/no-gh/git"

  run with_path "$BATS_TEST_TMPDIR/no-gh" steps 01_check_tools.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ gh not found"* ]]
}

@test "01 stops when gh is not logged in" {
  GH_EXIT_CODE=1 run steps 01_check_tools.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh auth login"* ]]
}

# ── 05_branch_prepare ────────────────────────────────────────────────────────

@test "05 creates the setup branch from origin's base branch" {
  run steps 05_branch_prepare.sh
  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = chore/repokit-setup ]
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ]
}

@test "05 stops when the branch it runs from is not on origin" {
  git checkout -qb feature

  run steps 05_branch_prepare.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"branch feature is not on origin"* ]]
}

@test "05 rebases an existing setup branch onto the base branch" {
  steps 05_branch_prepare.sh
  git checkout -q master
  git commit -q --allow-empty -m "chore: newer master"
  git push -q origin master

  run steps 05_branch_prepare.sh
  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = chore/repokit-setup ]
  git merge-base --is-ancestor origin/master HEAD
}

@test "05 for dotfiles stays on the current branch" {
  export LANGUAGE=dotfiles

  run steps 05_branch_prepare.sh
  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = master ]
}

# ── 06_workflows ─────────────────────────────────────────────────────────────

@test "06 writes the wrappers with placeholders filled, as one repokit commit" {
  run steps 06_workflows.sh
  [ "$status" -eq 0 ]

  for file in tests integration release; do
    [ -f ".github/workflows/$file.yml" ]
    [ "$(last_author ".github/workflows/$file.yml")" = repokit@djachenko ]
  done
  [ "$(cat .github/workflows/*.yml | grep -c '{{')" -eq 0 ]
  # A checkout has no VERSION file, so the wrappers point at master.
  grep -q 'python-tests.yml@master' .github/workflows/tests.yml
}

@test "06 re-run adds no commits" {
  steps 06_workflows.sh
  before=$(commit_count)

  run steps 06_workflows.sh
  [ "$status" -eq 0 ]
  [ "$(commit_count)" -eq "$before" ]
}

@test "06 leaves a workflow edited by the user alone, unless forced" {
  steps 06_workflows.sh
  echo "# mine" > .github/workflows/tests.yml
  git commit -qam "ci: my tests"

  run steps 06_workflows.sh
  [ "$status" -eq 0 ]
  [ "$(cat .github/workflows/tests.yml)" = "# mine" ]

  REPOKIT_FORCE=true run steps 06_workflows.sh
  [ "$status" -eq 0 ]
  [ "$(last_author .github/workflows/tests.yml)" = repokit@djachenko ]
}

# ── 07_ruleset ───────────────────────────────────────────────────────────────

@test "07 posts a valid ruleset requiring the wrappers' checks" {
  steps 06_workflows.sh

  run steps 07_ruleset.sh
  [ "$status" -eq 0 ]

  checks=$(ruleset_body | jq -r '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks | length')
  [ "$checks" -gt 0 ]
  [ "$(ruleset_body | jq '.bypass_actors | length')" -eq 0 ]
}

@test "07 puts the app from .repokit into bypass_actors" {
  steps 06_workflows.sh
  "$REPOKORE" config set app_id 12345

  run steps 07_ruleset.sh
  [ "$status" -eq 0 ]
  [ "$(ruleset_body | jq '.bypass_actors[0].actor_id')" -eq 12345 ]
}

@test "07 replaces a ruleset that already exists" {
  steps 06_workflows.sh
  echo 777 > "$GH_RESPONSE_DIR/api"

  run steps 07_ruleset.sh
  [ "$status" -eq 0 ]
  grep -q '^=== gh api repos/tester/demo/rulesets/777 --method DELETE$' "$GH_CALLS_LOG"
}

# ── 08_branch_push ───────────────────────────────────────────────────────────

@test "08 pushes the setup branch and opens a PR into the base branch" {
  run steps 05_branch_prepare.sh 06_workflows.sh 08_branch_push.sh
  [ "$status" -eq 0 ]

  git ls-remote --exit-code --heads origin chore/repokit-setup
  grep -q '^=== gh pr create .* --base master$' "$GH_CALLS_LOG"
}

@test "08 with nothing new neither pushes nor opens a PR" {
  run steps 05_branch_prepare.sh 08_branch_push.sh
  [ "$status" -eq 0 ]

  [[ "$output" == *"Already up to date"* ]]
  [ ! -f "$GH_CALLS_LOG" ]
}
