#!/usr/bin/env bats

# The python-versions action against the real setup-python manifest: the
# matrix it builds starts at requires-python and runs up to the newest stable
# release. The match is a prefix through 3.15, so a new release extends the
# list without breaking the test.

setup() {
  cd "$BATS_TEST_TMPDIR"
}

versions_for() {
  printf '[project]\n%s\n' "$1" > pyproject.toml
  python3 "$BATS_TEST_DIRNAME/../.github/actions/python-versions/get_versions.py"
}

@test "a lower bound starts the matrix there" {
  run versions_for 'requires-python = ">=3.12"'
  [ "$status" -eq 0 ]
  [[ "$output" == 'versions=["3.12", "3.13", "3.14", "3.15"'* ]]
}

@test "an upper bound on the major does not cut the matrix" {
  run versions_for 'requires-python = ">=3.11,<4"'
  [ "$status" -eq 0 ]
  [[ "$output" == 'versions=["3.11", "3.12", "3.13", "3.14", "3.15"'* ]]
}

@test "a compatible-release bound starts the matrix at its minor" {
  run versions_for 'requires-python = "~=3.13"'
  [ "$status" -eq 0 ]
  [[ "$output" == 'versions=["3.13", "3.14", "3.15"'* ]]
}

@test "an end-of-life lower bound is still tested" {
  run versions_for 'requires-python = ">=3.8"'
  [ "$status" -eq 0 ]
  [[ "$output" == 'versions=["3.8", "3.9", "3.10", "3.11", "3.12", "3.13", "3.14", "3.15"'* ]]
}

@test "no requires-python falls back to 3.11" {
  run versions_for 'name = "demo"'
  [ "$status" -eq 0 ]
  [[ "$output" == 'versions=["3.11", "3.12", "3.13", "3.14", "3.15"'* ]]
}
