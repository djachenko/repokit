#!/usr/bin/env bats

# languages/python/06_language_setup.sh, run with bash — the way the
# orchestrator runs it — against a real repository and the real repokore.

load helpers

setup() {
  setup_repokit_env
  setup_repo
}

python_setup() {
  bash "$SCRIPT_DIR/languages/python/06_language_setup.sh"
}

@test "first run writes pyproject, the package and the skill, each as a repokit commit" {
  ASK_YN=y run python_setup
  [ "$status" -eq 0 ]

  [ -f pyproject.toml ]
  [ -f src/demo/__init__.py ]
  [ -f .claude/skills/repokit.md ]
  [ "$(last_author pyproject.toml)" = repokit@djachenko ]
  [ "$(last_author src/demo/__init__.py)" = repokit@djachenko ]
  [ "$(last_author .claude/skills/repokit.md)" = repokit@djachenko ]
}

# merge-pyproject exits 3 for "nothing to change". The step must read that as
# "no commit", not as a failure that aborts the run under set -e.
@test "a re-run with nothing to change adds no commits" {
  python_setup
  before=$(commit_count)

  IS_FIRST_SETUP=false run python_setup
  [ "$status" -eq 0 ]
  [ "$(commit_count)" -eq "$before" ]
}

# Simulates a repo set up by an older repokit, whose template had no license:
# the hash on record is not the current template's, so the key the template
# gained is merged in and committed.
@test "a re-run after the template changed commits the merge" {
  python_setup
  grep -v '^license = ' pyproject.toml > pyproject.old
  mv pyproject.old pyproject.toml
  git commit -qam "chore: older template"
  "$REPOKORE" config set template_hash outdated
  before=$(commit_count)

  IS_FIRST_SETUP=false run python_setup
  [ "$status" -eq 0 ]
  [ "$(commit_count)" -eq $((before + 1)) ]
  [ "$(git log -1 --format=%s)" = "chore: [repokit] update pyproject.toml" ]
  grep -q '^license = "MIT"$' pyproject.toml
}

# A forced write over a file that already matches stages nothing; committing
# nothing would fail and take the run down with it.
@test "--force-pyproject over an up-to-date file succeeds without a commit" {
  python_setup
  before=$(commit_count)

  IS_FIRST_SETUP=false REPOKIT_FORCE=true run python_setup
  [ "$status" -eq 0 ]
  [ "$(commit_count)" -eq "$before" ]
}

@test "the package is not scaffolded on a re-run" {
  IS_FIRST_SETUP=false run python_setup
  [ "$status" -eq 0 ]
  [ ! -e src/demo ]
}
