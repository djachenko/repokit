#!/usr/bin/env bats

# The dotfiles language: its setup step, which keeps the tooling scripts in the
# user's repo current, and the scripts themselves as they run there.

load helpers

setup() {
  setup_repokit_env
  export LANGUAGE=dotfiles
  setup_repo
}

dotfiles_setup() {
  bash "$SCRIPT_DIR/languages/dotfiles/06_language_setup.sh"
}

@test "setup writes every tooling file and commits them as repokit" {
  run dotfiles_setup
  [ "$status" -eq 0 ]

  source "$SCRIPT_DIR/languages/dotfiles/templates/manifest"
  for file in $DOTFILES_TOOLING; do
    [ -f "$file" ]
    [ "$(last_author "$file")" = repokit@djachenko ]
  done
  [ -x install ]
  [ -x commit ]
}

@test "setup adds the gitignore entries once" {
  dotfiles_setup
  dotfiles_setup

  while IFS= read -r entry; do
    [ "$(grep -cxF "$entry" .gitignore)" -eq 1 ]
  done < "$SCRIPT_DIR/languages/dotfiles/templates/gitignore"
}

@test "the binary path is filled into commit" {
  dotfiles_setup

  grep -qF "REPOKORE=\"$REPOKORE\"" commit
  # Not `! grep`: a negated command never trips set -e, so it cannot fail a test.
  [ "$(grep -c '{{' commit)" -eq 0 ]
}

@test "a re-run adds no commits" {
  dotfiles_setup
  before=$(commit_count)

  run dotfiles_setup
  [ "$status" -eq 0 ]
  [ "$(commit_count)" -eq "$before" ]
}

@test "an outdated install committed by repokit is updated" {
  dotfiles_setup
  echo "# old" > install
  git add install
  repokit_commit "old install"

  run dotfiles_setup
  [ "$status" -eq 0 ]
  cmp -s install "$SCRIPT_DIR/languages/dotfiles/templates/install"
}

@test "an install edited by the user is left alone, with a hint" {
  dotfiles_setup
  echo "# mine" > install
  git commit -qam "chore: my install"

  run dotfiles_setup
  [ "$status" -eq 0 ]
  [ "$(cat install)" = "# mine" ]
  output_has "delete it and re-run"
}

# install links the repo into $HOME. The tooling lives in the repo but is not
# a dotfile: none of it may end up in $HOME.
@test "install links the dotfiles into HOME and none of the tooling" {
  dotfiles_setup
  echo "export A=1" > .zshrc
  export HOME="$BATS_TEST_TMPDIR/home"
  export LAUNCHCTL_CALLS_LOG="$BATS_TEST_TMPDIR/launchctl.log"
  mkdir -p "$HOME/Library/LaunchAgents"

  run ./install
  [ "$status" -eq 0 ]

  [ -L "$HOME/.zshrc" ]
  source "$SCRIPT_DIR/languages/dotfiles/templates/manifest"
  for file in $DOTFILES_TOOLING; do
    [ ! -e "$HOME/$file" ]
  done
  grep -q "=== launchctl load $HOME/Library/LaunchAgents/" "$LAUNCHCTL_CALLS_LOG"
}

# commit runs from launchd, which sets no XDG_DATA_HOME: the binary has to be
# found from the path written in at setup, not looked up at run time.
@test "commit finds repokore without XDG_DATA_HOME" {
  XDG_DATA_HOME="$BATS_TEST_TMPDIR/xdg" dotfiles_setup
  echo "export A=1" > .zshrc
  before=$(commit_count)

  run env -u XDG_DATA_HOME ./commit
  [ "$status" -eq 0 ]
  [ "$(commit_count)" -gt "$before" ]
  [ -z "$(git status --porcelain)" ]
}

# Without -z git quotes such paths, and `git add` cannot find the quoted name.
@test "commit takes non-ASCII, spaced and renamed paths" {
  dotfiles_setup
  echo a > old.txt
  git add old.txt
  git commit -qm "chore: old"
  git mv old.txt new.txt
  echo b > "заметки.md"
  echo c > "with space.txt"

  run ./commit
  [ "$status" -eq 0 ]
  [ -z "$(git status --porcelain)" ]
  git -c core.quotePath=false ls-files | grep -qxF "заметки.md"
  git ls-files | grep -qxF "with space.txt"
  git ls-files | grep -qxF new.txt
}

# ── adopt ────────────────────────────────────────────────────────────────────

adopt_setup() {
  dotfiles_setup
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config/app"
  echo "x = 1" > "$HOME/.config/app/conf"
}

@test "adopt moves a file into the repo and leaves a link behind" {
  adopt_setup

  run ./adopt "$HOME/.config/app/conf"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/app/conf" ]
  [ "$(cat .config/app/conf)" = "x = 1" ]
  [ "$(cat "$HOME/.config/app/conf")" = "x = 1" ]
}

@test "adopt without an argument prints usage" {
  adopt_setup

  run ./adopt
  [ "$status" -eq 1 ]
  output_has "Usage: adopt <file>"
}

@test "adopt refuses a file outside HOME" {
  adopt_setup
  echo y > "$BATS_TEST_TMPDIR/elsewhere"

  run ./adopt "$BATS_TEST_TMPDIR/elsewhere"
  [ "$status" -eq 1 ]
  output_has "is outside \$HOME"
  [ -f "$BATS_TEST_TMPDIR/elsewhere" ]
}

@test "adopt refuses a file that is already a link" {
  adopt_setup
  ./adopt "$HOME/.config/app/conf"

  run ./adopt "$HOME/.config/app/conf"
  [ "$status" -eq 1 ]
  output_has "already a symlink"
}

@test "adopt does not overwrite what the repo already has" {
  adopt_setup
  mkdir -p .config/app
  echo "repo" > .config/app/conf

  run ./adopt "$HOME/.config/app/conf"
  [ "$status" -eq 1 ]
  output_has "already exists"
  [ "$(cat .config/app/conf)" = repo ]
  [ ! -L "$HOME/.config/app/conf" ]
}
