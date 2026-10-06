#!/usr/bin/env bats

# hooks/pre-push, linked into the repo the way the orchestrator links it and
# fired by a real git push to the bare origin.

load helpers

setup() {
  setup_repokit_env
  setup_repo
  # A symlink, as in the orchestrator: the hook finds repokore through it.
  ln -s "$SCRIPT_DIR/hooks/pre-push" .git/hooks/pre-push
}

foreign_commit() {
  git commit -q --allow-empty --author="stranger <stranger@example.com>" -m "chore: foreign"
}

@test "a push of the user's own commits goes through" {
  git commit -q --allow-empty -m "chore: mine"

  run git push origin master
  [ "$status" -eq 0 ]
}

# With no terminal the prompt reads nothing, which is the default: deny. With
# one it would wait for a keypress, so the test only runs without it — in CI.
@test "a push with a foreign author is refused and names the commit" {
  if (: < /dev/tty) 2> /dev/null; then
    skip "a terminal is attached: the hook would prompt"
  fi
  foreign_commit

  run git push origin master
  [ "$status" -ne 0 ]
  output_has "<stranger@example.com> chore: foreign"
  [ "$(git rev-parse origin/master)" != "$(git rev-parse master)" ]
}

@test "repokit.allowedEmail lets a foreign author through" {
  git config --local --add repokit.allowedEmail stranger@example.com
  foreign_commit

  run git push origin master
  [ "$status" -eq 0 ]
}

@test "repokit.allowForeignAuthors lets any author through" {
  git config repokit.allowForeignAuthors true
  foreign_commit

  run git push origin master
  [ "$status" -eq 0 ]
}

# A new branch has no remote sha to diff against: the range is "everything not
# on any remote". A foreign commit origin already has must not be asked about
# again.
@test "a new branch checks only the commits origin does not have" {
  git config repokit.allowForeignAuthors true
  foreign_commit
  git push -q origin master
  git config --unset repokit.allowForeignAuthors

  git checkout -qb feature
  git commit -q --allow-empty -m "chore: mine"

  run git push origin feature
  [ "$status" -eq 0 ]
}

@test "deleting a remote branch is not checked" {
  git config repokit.allowForeignAuthors true
  git checkout -qb feature
  foreign_commit
  git push -q origin feature
  git config --unset repokit.allowForeignAuthors

  run git push origin --delete feature
  [ "$status" -eq 0 ]
}
