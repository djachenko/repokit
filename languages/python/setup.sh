#!/bin/bash

set -e

SKILL_SRC="$SCRIPT_DIR/languages/python/repokit_skill.md"
SKILL_DST=".claude/skills/repokit.md"

TPL="$SCRIPT_DIR/languages/python/pyproject.toml"

new_content=$(sed "s/{{REPO}}/$REPO/g; s/{{OWNER}}/$OWNER/g" "$TPL")

echo "Create Claude skill for repokit integration? [y/N]"
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  mkdir -p .claude/skills
  cp "$SKILL_SRC" "$SKILL_DST"
  if git check-ignore -q "$SKILL_DST" 2> /dev/null; then
    echo "→ Created $SKILL_DST (not committed: path is gitignored)"
  else
    git add "$SKILL_DST"
    repokit_commit "add Claude skill for repokit integration"
  fi
fi

if [[ -f "pyproject.toml" && "${REPOKIT_FORCE:-false}" == false ]]; then
  if [[ "$new_content" != "$(cat pyproject.toml)" ]]; then
    echo "→ Writing pyproject.toml... skip (modified by user — use --force-pyproject to overwrite)"
  fi
else
  echo "→ Writing pyproject.toml..."
  echo "$new_content" > pyproject.toml
  git add pyproject.toml
  repokit_commit "add pyproject.toml"
fi
