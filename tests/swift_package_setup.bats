#!/usr/bin/env bats

# languages/swift-package/06_language_setup.sh, run with bash — the way the
# orchestrator runs it — against a real repository and the real repokore.

load helpers

setup() {
  setup_repokit_env
  export LANGUAGE=swift-package
  setup_repo
}

swift_setup() {
  bash "$SCRIPT_DIR/languages/swift-package/06_language_setup.sh"
}

@test "first run writes the tooling and the repo's SwiftLint config as repokit" {
  run swift_setup
  [ "$status" -eq 0 ]

  for file in .swiftlint_base.yml Tests/.swiftlint.yml cog.toml .claude/skills/repokit.md .swiftlint.yml .gitignore; do
    [ -f "$file" ]
    [ "$(last_author "$file")" = repokit@djachenko ]
  done
}

@test "a re-run adds no commits" {
  swift_setup
  before=$(commit_count)

  run swift_setup
  [ "$status" -eq 0 ]
  [ "$(commit_count)" -eq "$before" ]
}

@test "gitignore gets the template's patterns once and none of its comments" {
  swift_setup
  swift_setup

  [ "$(grep -cx '.build/' .gitignore)" -eq 1 ]
  [ "$(grep -cx '.swiftpm' .gitignore)" -eq 1 ]
  [ "$(grep -cx 'Package.resolved' .gitignore)" -eq 1 ]
  [ "$(grep -c '^#' .gitignore)" -eq 0 ]
}

# .swiftlint.yml is the repo's from the first run: even one repokit wrote and
# nobody touched is not replaced when the template changes.
@test "the repo's .swiftlint.yml is written once and never updated" {
  swift_setup
  echo "# older template" >> .swiftlint.yml
  git add .swiftlint.yml
  repokit_commit "older swiftlint config"

  run swift_setup
  [ "$status" -eq 0 ]
  [ "$(tail -1 .swiftlint.yml)" = "# older template" ]
}

@test "an existing .swiftlint.yml without the base is kept, with a note" {
  echo "line_length: 100" > .swiftlint.yml
  git add .swiftlint.yml
  git commit -qm "chore: own swiftlint config"

  run swift_setup
  [ "$status" -eq 0 ]
  [ "$(cat .swiftlint.yml)" = "line_length: 100" ]
  output_has "parent_config: .swiftlint_base.yml"
}

@test "a gitignored skill is written but not committed, and the run goes on" {
  echo ".claude/" > .gitignore
  git add .gitignore
  git commit -qm "chore: ignore .claude"

  run swift_setup
  [ "$status" -eq 0 ]
  [ -f .claude/skills/repokit.md ]
  [ "$(git ls-files .claude | wc -l)" -eq 0 ]
  [ "$(last_author cog.toml)" = repokit@djachenko ]
}

# The three configs chain: base → repo → Tests/. Checked with the real
# SwiftLint, so only where it is installed — the bats job runs on Linux.
@test "the base applies strictly in Sources and the force rules are off in Tests" {
  command -v swiftlint > /dev/null || skip "swiftlint not installed"
  swift_setup
  mkdir -p Sources/Demo Tests/DemoTests
  printf 'let value = Int("1")!\n' > Sources/Demo/Demo.swift
  printf 'let value = Int("1")!\n' > Tests/DemoTests/DemoTests.swift

  run swiftlint lint --quiet
  [ "$status" -ne 0 ]
  output_has "Sources/Demo/Demo.swift"
  output_has "force_unwrapping"
  [ "$(echo "$output" | grep -c 'Tests/DemoTests')" -eq 0 ]
}

@test "strict: false in the repo's config turns the failure back into a warning" {
  command -v swiftlint > /dev/null || skip "swiftlint not installed"
  swift_setup
  grep -v '^strict: ' .swiftlint.yml > .swiftlint.new
  echo "strict: false" >> .swiftlint.new
  mv .swiftlint.new .swiftlint.yml
  mkdir -p Sources/Demo
  printf 'let value = Int("1")!\n' > Sources/Demo/Demo.swift

  run swiftlint lint --quiet
  [ "$status" -eq 0 ]
  output_has "warning"
}
