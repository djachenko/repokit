#!/usr/bin/env bats

# languages/swift-app/06_language_setup.sh, run with bash — the way the
# orchestrator runs it — against a real repository and the real repokore.

load helpers

setup() {
  setup_repokit_env
  export LANGUAGE=swift-app
  setup_repo
}

swift_app_setup() {
  bash "$SCRIPT_DIR/languages/swift-app/06_language_setup.sh"
}

# An app in a subfolder, the way photochem lies: a workspace over the project
# and a local package, one test plan covering the tests of both.
make_app() {
  mkdir -p App/App.xcworkspace App/App.xcodeproj App/AppTests App/Core/Tests/CoreTests
  printf 'MARKETING_VERSION = 0.0.0;\nCURRENT_PROJECT_VERSION = 1;\nMARKETING_VERSION = 0.0.0;\n' > App/App.xcodeproj/project.pbxproj
  cat > App/App.xctestplan << 'EOF'
{
  "testTargets" : [
    { "target" : { "containerPath" : "container:App.xcodeproj", "name" : "AppTests" } },
    { "target" : { "containerPath" : "container:Core", "name" : "CoreTests" } }
  ]
}
EOF
  touch App/AppTests/AppTests.swift App/Core/Tests/CoreTests/CoreTests.swift
  git add App
  git commit -qm "feat: app"
}

@test "first run writes the tooling next to the project and in every test folder" {
  make_app

  run swift_app_setup
  [ "$status" -eq 0 ]

  for file in App/.swiftlint_base.yml App/.swiftlint.yml App/AppTests/.swiftlint.yml \
    App/Core/Tests/CoreTests/.swiftlint.yml cog.toml .claude/skills/repokit.md .gitignore; do
    [ -f "$file" ]
    [ "$(last_author "$file")" = repokit@djachenko ]
  done
}

@test "a re-run adds no commits" {
  make_app
  swift_app_setup
  before=$(commit_count)

  run swift_app_setup
  [ "$status" -eq 0 ]
  [ "$(commit_count)" -eq "$before" ]
}

@test "a project without a workspace is found the same way" {
  make_app
  rmdir App/App.xcworkspace

  run swift_app_setup
  [ "$status" -eq 0 ]
  [ -f App/.swiftlint_base.yml ]
}

# At the root, the project.xcworkspace Xcode keeps inside every .xcodeproj is
# within reach of the workspace search — and must not pass for one.
@test "a project at the root is found past its inner project.xcworkspace" {
  mkdir -p App.xcodeproj/project.xcworkspace

  run swift_app_setup
  [ "$status" -eq 0 ]
  [ -f .swiftlint_base.yml ]
}

@test "no project is an error" {
  run swift_app_setup
  [ "$status" -ne 0 ]
  output_has "found: none"
}

@test "two workspaces are an error, not a guess" {
  make_app
  mkdir Other.xcworkspace

  run swift_app_setup
  [ "$status" -ne 0 ]
  output_has "Other.xcworkspace"
}

@test "a test target without its folder is a note, and the run goes on" {
  make_app
  git rm -rq App/Core
  git commit -qm "chore: drop core"

  run swift_app_setup
  [ "$status" -eq 0 ]
  output_has "no folder named CoreTests"
  [ -f App/AppTests/.swiftlint.yml ]
}

# SwiftPM checks dependencies out with their own test plans, the way Yams
# lies in photochem — their targets are not the app's.
@test "a test plan in a SwiftPM checkout is not read" {
  make_app
  mkdir -p App/Core/.build/checkouts/Dep/DepTests
  echo '{ "testTargets" : [ { "target" : { "name" : "DepTests" } } ] }' > App/Core/.build/checkouts/Dep/Dep.xctestplan

  run swift_app_setup
  [ "$status" -eq 0 ]
  [ "$(grep -c 'DepTests' <<< "$output")" -eq 0 ]
}

# Unlike a package, an app commits its pinned dependencies.
@test "Package.resolved stays tracked, the build folders are ignored" {
  make_app
  swift_app_setup

  [ "$(grep -cx 'Package.resolved' .gitignore)" -eq 0 ]
  [ "$(grep -cx '.build/' .gitignore)" -eq 1 ]
}

# The hook as cog runs it: from cog.toml, with {{version}} filled in. Run
# here directly — the bats job has no cog — so this checks the command, not
# cog's handling of it.
@test "the bump hook writes the version to every MARKETING_VERSION and nothing else" {
  make_app
  swift_app_setup
  hook=$(grep -o '"find .*"' cog.toml)
  hook=${hook:1:${#hook}-2}

  eval "${hook//\{\{version\}\}/1.2.3}"

  [ "$(grep -c 'MARKETING_VERSION = 1.2.3;' App/App.xcodeproj/project.pbxproj)" -eq 2 ]
  grep -qx 'CURRENT_PROJECT_VERSION = 1;' App/App.xcodeproj/project.pbxproj
}
