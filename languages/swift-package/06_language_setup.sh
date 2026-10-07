#!/bin/bash

set -e

TPL="$SCRIPT_DIR/languages/swift-package/templates"

# shellcheck source=languages/swift-package/tooling.sh
source "$SCRIPT_DIR/languages/swift-package/tooling.sh"

echo "→ Writing Swift tooling..."

templates=("$TPL/swiftlint_base.yml" "$TPL/swiftlint_tests.yml" "$TPL/cog.toml" "$TPL/repokit_skill.md")
destinations=(.swiftlint_base.yml Tests/.swiftlint.yml cog.toml .claude/skills/repokit.md)

sync_tooling
write_lint_config . "$TPL/swiftlint.yml"
gitignore_patterns "$TPL/gitignore" | add_gitignore
commit_tooling
