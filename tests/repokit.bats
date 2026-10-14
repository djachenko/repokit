#!/usr/bin/env bats

# The orchestrator end to end, on a repo that already has its origin: every
# step for real except gh, which answers "the GitHub repo exists".

load helpers

setup() {
  setup_repokit_env
  setup_repo
  # gh api user --jq .login is how the orchestrator learns the owner.
  echo tester > "$GH_RESPONSE_DIR/api"
  # The pre-push hook repokit links in treats repokit's own author like any
  # other: it is allowed by hand, once per machine, not by repokit.
  git config --global --add repokit.allowedEmail repokit@djachenko
}

# stdin from /dev/null: ask_yn reads a keypress, and nothing typed means no.
repokit() {
  "$REPOKIT_ROOT/repokit" "$@" < /dev/null
}

@test "a first run sets the repo up and opens the PR" {
  run repokit --language python
  [ "$status" -eq 0 ]

  [ "$("$REPOKORE" config get language)" = python ]
  [ "$("$REPOKORE" config get base_branch)" = master ]
  [ -L .git/hooks/pre-push ]
  git ls-remote --exit-code --heads origin chore/repokit-setup
  grep -q '^=== gh pr create .* --base master$' "$GH_CALLS_LOG"
}

# While the setup PR is open the branch is still ahead of master, so the run
# pushes again — the same commits, which leaves origin as it was.
@test "a re-run with nothing new changes nothing" {
  repokit --language python
  before=$(git rev-parse HEAD)

  run repokit
  [ "$status" -eq 0 ]
  [ "$(git rev-parse HEAD)" = "$before" ]
  [ "$(git ls-remote origin refs/heads/chore/repokit-setup | cut -f1)" = "$before" ]
}

@test "an existing GitHub repo gets auto-merge" {
  run repokit --language python
  [ "$status" -eq 0 ]
  grep -q '^=== gh api repos/tester/demo --method PATCH --field allow_auto_merge=true$' "$GH_CALLS_LOG"
}

# No GitHub repo yet: gh repo view fails, so 03 creates it and adds an SSH
# origin, which insteadOf points back at the local bare one. "r" answers the
# visibility prompt.
@test "a new GitHub repo gets auto-merge" {
  git remote remove origin
  git config --global url."$BATS_TEST_TMPDIR/origin.git".insteadOf git@github.com:tester/demo.git

  GH_FAIL="repo view" run "$REPOKIT_ROOT/repokit" --language python <<< r
  [ "$status" -eq 0 ]
  grep -q '^=== gh repo create tester/demo --private$' "$GH_CALLS_LOG"
  grep -q '^=== gh api repos/tester/demo --method PATCH --field allow_auto_merge=true$' "$GH_CALLS_LOG"
}

# In a worktree .git is a file, not a directory; hooks live in the main repo.
@test "run in a worktree, the hook lands where git runs hooks from" {
  main="$PWD"
  git worktree add -q -b wt "$BATS_TEST_TMPDIR/wt/demo"
  cd "$BATS_TEST_TMPDIR/wt/demo"
  git push -q -u origin wt

  run repokit --language python
  [ "$status" -eq 0 ]
  [ -L "$main/.git/hooks/pre-push" ]
}

# The installed tree without bin/repokore: the run must stop before touching
# anything rather than skip what needs the binary.
@test "without repokore the run stops before any change" {
  install="$BATS_TEST_TMPDIR/install"
  mkdir "$install"
  cp -R "$REPOKIT_ROOT/repokit" "$REPOKIT_ROOT/scripts" "$REPOKIT_ROOT/init" "$REPOKIT_ROOT/languages" "$install"
  before=$(git rev-parse HEAD)

  run "$install/repokit" --language python
  [ "$status" -eq 1 ]
  output_has "repokore not found"
  [ "$(git rev-parse HEAD)" = "$before" ]
  [ ! -e .repokit ]
}
