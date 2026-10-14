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

# One case per line: the pyproject line, a tab, the expected start of the matrix.
# The failing case is printed, so a red run names it.
@test "the matrix starts at requires-python and reaches the newest release" {
  local requires expected
  while IFS=$'\t' read -r requires expected; do
    run versions_for "$requires"
    echo "case: $requires → $output"
    [ "$status" -eq 0 ]
    # || false: bash 3.2 (macOS) does not fail a test on [[ ]] mid-function.
    [[ "$output" == "versions=[$expected"* ]] || false
  done <<'EOF'
requires-python = ">=3.12"	"3.12", "3.13", "3.14", "3.15"
requires-python = ">=3.11,<4"	"3.11", "3.12", "3.13", "3.14", "3.15"
requires-python = "~=3.13"	"3.13", "3.14", "3.15"
requires-python = ">=3.8"	"3.8", "3.9", "3.10", "3.11", "3.12", "3.13", "3.14", "3.15"
name = "demo"	"3.11", "3.12", "3.13", "3.14", "3.15"
EOF
}

# An empty matrix would pass here and fail later in the workflow, with an
# error about the matrix rather than about requires-python.
@test "a requires-python above every release fails and names the bound" {
  run versions_for 'requires-python = ">=3.99"'
  [ "$status" -ne 0 ]
  [[ "$output" == *">= 3.99"* ]]
}
