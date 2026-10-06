#!/usr/bin/env bats

# install.sh against a fake GitHub: curl and uname come from tests/bin/install,
# the release is a tarball built here, and $HOME is the test's own.

load helpers

setup() {
  export PATH="$BATS_TEST_DIRNAME/bin/install:$PATH"
  export HOME="$BATS_TEST_TMPDIR/home"
  export SHELL=/bin/zsh
  export CURL_CALLS_LOG="$BATS_TEST_TMPDIR/curl.log"
  export FAKE_OS=Linux FAKE_ARCH=x86_64
  unset XDG_DATA_HOME
  INSTALL_DIR="$HOME/.local/share/repokit"
  # Only $HOME itself: a fresh machine may have no ~/.local/share yet.
  mkdir -p "$HOME"
  release v1.0.0
}

# A source tarball for $1 shaped like GitHub's: one top-level repokit-<tag>/.
release() {
  export FAKE_VERSION="$1" FAKE_TARBALL="$BATS_TEST_TMPDIR/$1.tar.gz"
  local tree="$BATS_TEST_TMPDIR/src/repokit-$1"
  mkdir -p "$tree/init" "$tree/hooks"
  touch "$tree/repokit" "$tree/init/01_check_tools.sh" "$tree/hooks/pre-push" "$tree/install.sh"
  tar czf "$FAKE_TARBALL" -C "$BATS_TEST_TMPDIR/src" "repokit-$1"
}

install_repokit() {
  bash "$REPOKIT_ROOT/install.sh"
}

@test "a fresh install puts the binary in place and hooks the shell in once" {
  run install_repokit
  [ "$status" -eq 0 ]

  [ -x "$INSTALL_DIR/bin/repokore" ]
  [ -x "$INSTALL_DIR/repokit" ]
  [ "$(cat "$INSTALL_DIR/VERSION")" = v1.0.0 ]
  [ ! -e "$INSTALL_DIR/install.sh" ]
  [ "$(grep -c 'repokit/shell.sh' "$HOME/.zshrc")" -eq 1 ]
}

@test "an update replaces the install and keeps one rc line" {
  install_repokit
  release v1.1.0

  run install_repokit
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated: repokit v1.0.0 → v1.1.0"* ]]
  [ "$(cat "$INSTALL_DIR/VERSION")" = v1.1.0 ]
  [ "$(grep -c 'repokit/shell.sh' "$HOME/.zshrc")" -eq 1 ]
}

@test "the installed version is not downloaded again" {
  install_repokit
  : > "$CURL_CALLS_LOG"

  run install_repokit
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already up to date"* ]]
  [ "$(grep -vc '/releases/latest$' "$CURL_CALLS_LOG")" -eq 0 ]
}

# Linux says aarch64 where the release asset says arm64.
@test "aarch64 fetches the arm64 binary" {
  FAKE_ARCH=aarch64 run install_repokit
  [ "$status" -eq 0 ]
  grep -q '/releases/download/v1.0.0/repokore-linux-arm64$' "$CURL_CALLS_LOG"
}

@test "x86_64 fetches the amd64 binary" {
  FAKE_OS=Darwin run install_repokit
  [ "$status" -eq 0 ]
  grep -q '/releases/download/v1.0.0/repokore-darwin-amd64$' "$CURL_CALLS_LOG"
}

# The binary is fetched before the old install is moved aside: a release
# without one must leave a working install as it was.
@test "a release without the binary leaves the current install untouched" {
  install_repokit
  release v1.1.0

  FAKE_NO_BINARY=1 run install_repokit
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not download repokore for linux/amd64"* ]]
  [ "$(cat "$INSTALL_DIR/VERSION")" = v1.0.0 ]
  [ -x "$INSTALL_DIR/bin/repokore" ]
}
