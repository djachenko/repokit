#!/bin/bash

set -e

SKILL_SRC="$SCRIPT_DIR/languages/python/repokit_skill.md"
SKILL_DST=".claude/skills/repokit.md"

TPL="$SCRIPT_DIR/languages/python/pyproject.toml"

# Substitute placeholders before any file comparisons so we diff final content,
# not the template with {{REPO}}/{{OWNER}} literals still in it.
new_content=$(sed "s/{{REPO}}/$REPO/g; s/{{OWNER}}/$OWNER/g" "$TPL")

# ── Claude skill ──────────────────────────────────────────────────────────────
#
# The skill tells Claude Code what repokit owns in this repo (workflows, version)
# and what not to do (edit workflows manually, bump version by hand).
# We update it silently on every run; first install asks for confirmation because
# the project may not use Claude Code at all.

if [[ -f "$SKILL_DST" ]] && cmp -s "$SKILL_SRC" "$SKILL_DST"; then
  # cmp -s: silent byte-for-byte compare; exit 0 means identical → nothing to do
  echo "→ $SKILL_DST is up to date, skipping"
elif [[ -f "$SKILL_DST" ]]; then
  cp "$SKILL_SRC" "$SKILL_DST"

  # If the path is gitignored the file still gets updated on disk but we don't
  # stage it — committing a gitignored path would silently succeed but confuse
  # anyone who clones the repo later and finds the file missing.
  if git check-ignore -q "$SKILL_DST" 2> /dev/null; then
    echo "→ Updated $SKILL_DST (not committed: path is gitignored)"
  else
    git add "$SKILL_DST"
    repokit_commit "update Claude skill for repokit integration"
  fi
elif ask_yn "Create Claude skill for repokit integration?"; then
  mkdir -p .claude/skills
  cp "$SKILL_SRC" "$SKILL_DST"

  if git check-ignore -q "$SKILL_DST" 2> /dev/null; then
    echo "→ Created $SKILL_DST (not committed: path is gitignored)"
  else
    git add "$SKILL_DST"
    repokit_commit "add Claude skill for repokit integration"
  fi
fi

# ── Package skeleton ──────────────────────────────────────────────────────────
#
# hatchling (the build backend in pyproject.toml) requires src/$REPO/ to exist.
# Without it, `pip install -e ".[test]"` fails and the integration CI is red
# from the first push. Only scaffold on first setup — don't overwrite user code.

if [[ "$IS_FIRST_SETUP" == true && ! -d "src/$REPO" ]]; then
  echo "→ Scaffolding src/$REPO/__init__.py..."
  mkdir -p "src/$REPO"
  touch "src/$REPO/__init__.py"
  git add "src/$REPO/__init__.py"
  repokit_commit "scaffold src/$REPO package"
fi

# ── pyproject.toml ────────────────────────────────────────────────────────────
#
# Skip if the user has modified the file (they added classifiers, dependencies,
# etc.) unless --force-pyproject was passed.  We compare against the rendered
# template, not the source, so a re-run with the same REPO/OWNER is a no-op.

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
