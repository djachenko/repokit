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
# Hash the rendered template to detect changes across runs.
# We compare template-to-template (not template-to-file) so user edits don't
# trigger unnecessary merges — only actual template updates do.

new_hash=$(printf '%s' "$new_content" | openssl dgst -sha256 | awk '{print $2}')

# Update a single key in .repokit without touching other fields.
repokit_set_field() {
  local key="$1" val="$2" tmp
  tmp=$(mktemp)
  grep -v "^${key}=" .repokit 2> /dev/null > "$tmp" || true
  printf '%s=%s\n' "$key" "$val" >> "$tmp"
  mv "$tmp" .repokit
}

if [[ "${REPOKIT_FORCE:-false}" == true ]]; then
  # --force-pyproject: overwrite entirely, no merge
  echo "→ Writing pyproject.toml (forced)..."
  printf '%s\n' "$new_content" > pyproject.toml
  git add pyproject.toml
  repokit_commit "update pyproject.toml"
  repokit_set_field "template_hash" "$new_hash"

elif [[ ! -f "pyproject.toml" ]]; then
  # First run: file doesn't exist yet, write template directly
  echo "→ Writing pyproject.toml..."
  printf '%s\n' "$new_content" > pyproject.toml
  git add pyproject.toml
  repokit_commit "add pyproject.toml"
  repokit_set_field "template_hash" "$new_hash"

else
  stored_hash=$(grep '^template_hash=' .repokit 2> /dev/null | cut -d= -f2 || true)

  if [[ "$new_hash" == "$stored_hash" ]]; then
    echo "→ pyproject.toml is up to date, skipping"
  else
    # Template changed — merge managed keys into user's file.
    MERGE_BIN="$SCRIPT_DIR/bin/merge_pyproject"

    if [[ ! -x "$MERGE_BIN" ]]; then
      echo "⚠ pyproject.toml template changed but merge tool not found — skipping merge"
      echo "  Reinstall repokit: curl -fsSL https://raw.githubusercontent.com/djachenko/repokit/master/install.sh | bash"
    fi

    if [[ -x "$MERGE_BIN" ]]; then
      tmpl_tmp=$(mktemp)
      # Always clean up temp file, even if merge fails or script is interrupted.
      trap 'rm -f "$tmpl_tmp"' EXIT
      printf '%s\n' "$new_content" > "$tmpl_tmp"

      echo "→ Merging pyproject.toml..."
      if "$MERGE_BIN" "$tmpl_tmp" pyproject.toml; then
        git add pyproject.toml
        repokit_commit "update pyproject.toml"
        repokit_set_field "template_hash" "$new_hash"
      else
        echo "✗ merge failed — pyproject.toml not updated"
      fi
    fi
  fi
fi
