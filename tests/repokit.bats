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

@test "a re-run with nothing new changes nothing" {
  repokit --language python
  before=$(git rev-parse HEAD)

  run repokit
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already up to date"* ]]
  [ "$(git rev-parse HEAD)" = "$before" ]
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
  [[ "$output" == *"repokore not found"* ]]
  [ "$(git rev-parse HEAD)" = "$before" ]
  [ ! -e .repokit ]
}
