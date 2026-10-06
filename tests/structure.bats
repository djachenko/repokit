#!/usr/bin/env bats

# Files every language must carry because the orchestrator calls them by path,
# with no fallback to init/. Renaming one in a single language breaks only that
# language, and only at the end of a real run — here it fails in milliseconds.

load helpers

# Fails the test, naming every language that has no $1.
assert_every_language_has() {
  local missing=() lang
  for lang in "$REPOKIT_ROOT"/languages/*/; do
    [[ -f "$lang/$1" ]] || missing+=("$lang")
  done
  echo "no $1 in: ${missing[*]}"
  [ ${#missing[@]} -eq 0 ]
}

# The orchestrator runs it directly with bash, not through run_step.
@test "every language has 06_language_setup.sh" {
  assert_every_language_has 06_language_setup.sh
}

# Both the default 08_branch_push.sh and the dotfiles override call it.
@test "every language has instructions.sh" {
  assert_every_language_has instructions.sh
}
