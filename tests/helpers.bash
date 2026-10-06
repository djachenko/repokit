# Loaded by every .bats file. Builds what the orchestrator would have built
# before a step runs: the exported variables, the exported functions, and a
# repository with an origin to push to.
#
# Nothing here is faked that the steps can actually run: git is real, with a
# local bare repository as origin, and repokore is the real binary — the seam
# between bash and repokore (exit codes, output) is exactly what Go tests miss.
# Only gh (network) and launchctl (absent on Linux) are shims, from tests/bin.

REPOKIT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# The functions are taken from the orchestrator's own text rather than written
# again here: a copy would keep passing after the original changed. awk prints
# each from its "name() " line to the first closing brace at column 0.
load_orchestrator_functions() {
  local fn
  for fn in "$@"; do
    eval "$(awk -v head="$fn() " 'index($0, head) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$REPOKIT_ROOT/repokit")"
  done
}

setup_repokit_env() {
  export SCRIPT_DIR="$REPOKIT_ROOT"
  # The same file the orchestrator sources: sets $REPOKORE, and fails the test
  # outright when bin/repokore was not built.
  # shellcheck source=../scripts/repokore-env
  source "$SCRIPT_DIR/scripts/repokore-env"

  export LANGUAGE=python OWNER=tester REPO=demo IS_FIRST_SETUP=true
  export REPOKIT_AUTHOR="repokit <repokit@djachenko>"

  load_orchestrator_functions run_quiet repokit_commit run_step
  export -f run_quiet repokit_commit

  # The real one waits for a keypress. $ASK_YN is the answer the test gives.
  ask_yn() { [[ "${ASK_YN:-n}" == y ]]; }
  export -f ask_yn

  export PATH="$BATS_TEST_DIRNAME/bin:$PATH"
  export GH_CALLS_LOG="$BATS_TEST_TMPDIR/gh.log"
  export GH_RESPONSE_DIR="$BATS_TEST_TMPDIR/gh"
  mkdir -p "$GH_RESPONSE_DIR"

  # A git config of the test's own: the developer's global one (signing,
  # hooks, another default branch) must not decide whether a test passes.
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
  git config --global user.name tester
  git config --global user.email tester@example.com
  git config --global init.defaultBranch master
}

# A repository named $REPO with one user commit, pushed to a bare origin.
# Leaves the test inside it, as the orchestrator runs inside the user's repo.
setup_repo() {
  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  mkdir "$BATS_TEST_TMPDIR/$REPO"
  cd "$BATS_TEST_TMPDIR/$REPO" || return
  git init -q
  git remote add origin "$BATS_TEST_TMPDIR/origin.git"
  git commit -q --allow-empty -m "chore: init"
  git push -q -u origin master
}

commit_count() {
  git rev-list --count HEAD
}

# Author of the last commit that touched $1.
last_author() {
  git log -1 --format=%ae -- "$1"
}
