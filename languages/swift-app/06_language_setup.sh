#!/bin/bash

set -e

TPL="$SCRIPT_DIR/languages/swift-app/templates"
SHARED="$SCRIPT_DIR/languages/swift-package/templates"

# shellcheck source=languages/swift-package/tooling.sh
source "$SCRIPT_DIR/languages/swift-package/tooling.sh"

echo "→ Writing Swift tooling..."

# The project may sit in a subfolder. A workspace wins over a project: it is
# what ties the app to its local packages. -maxdepth 2: the repo root and one
# folder down. project.xcworkspace is the one Xcode keeps inside every
# .xcodeproj, not a workspace of its own.
projects=$(find . -maxdepth 2 -name '*.xcworkspace' -not -name project.xcworkspace)
[[ -z "$projects" ]] && projects=$(find . -maxdepth 2 -name '*.xcodeproj')

# wc -l counts paths; an empty list is still one (empty) line, hence the
# separate -z check.
if [[ -z "$projects" || $(echo "$projects" | wc -l) -ne 1 ]]; then
  echo "Error: expected one .xcworkspace or .xcodeproj within two levels, found: ${projects:-none}"
  exit 1
fi

project_dir=$(dirname "$projects")

templates=("$SHARED/swiftlint_base.yml" "$TPL/cog.toml" "$TPL/repokit_skill.md")
destinations=("$project_dir/.swiftlint_base.yml" cog.toml .claude/skills/repokit.md)

# The test config goes in every test target's folder. The targets come from
# the test plans; the folder is named after the target, the way Xcode creates
# it — the project file is not read for it, its format differs between Xcode
# versions.
for plan in $(find "$project_dir" -name '*.xctestplan'); do
  for target in $(jq -r '.testTargets[].target.name' "$plan"); do
    tests_dir=$(find "$project_dir" -type d -name "$target" -not -path '*/.build/*' | head -1)

    if [[ -z "$tests_dir" ]]; then
      echo "  note: no folder named $target for the test config"
      continue
    fi

    templates+=("$SHARED/swiftlint_tests.yml")
    destinations+=("$tests_dir/.swiftlint.yml")
  done
done

sync_tooling
write_lint_config "$project_dir" "$TPL/swiftlint.yml"

# An app pins its dependencies: Package.resolved is committed, unlike in a
# package, where the consumer resolves them.
gitignore_patterns "$SHARED/gitignore" | grep -vx Package.resolved | add_gitignore
commit_tooling
