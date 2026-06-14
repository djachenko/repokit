#!/bin/bash

set -e

REPO="djachenko/repokit"
VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/repokit"

SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && SHELL_RC="$HOME/.bashrc"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading repokit..."
curl -fsSL "$TARBALL_URL" | tar xz -C "$TMP"

echo "Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mv "$TMP"/repokit-"$VERSION" "$INSTALL_DIR"
rm -f "$INSTALL_DIR/install.sh"
rm -rf "$INSTALL_DIR/.github" "$INSTALL_DIR/memory"
chmod +x "$INSTALL_DIR/repokit" "$INSTALL_DIR"/init/*.sh "$INSTALL_DIR"/hooks/*

LINE="export PATH=\"$INSTALL_DIR:\$PATH\""
if grep -qF "$INSTALL_DIR" "$SHELL_RC" 2> /dev/null; then
  echo "Already in PATH ($SHELL_RC)"
else
  echo "$LINE" >> "$SHELL_RC"
  echo "Added to $SHELL_RC. Restart shell or: source $SHELL_RC"
fi

git config --global core.hooksPath "$INSTALL_DIR/hooks"
echo "Git hooks configured globally"

OWNER_EMAIL=$(gh api user --jq '.email // empty' 2> /dev/null)
if [[ -z "$OWNER_EMAIL" ]]; then
  OWNER_EMAIL=$(git config --global user.email)
fi
if [[ -n "$OWNER_EMAIL" ]]; then
  git config --global repokit.ownerEmail "$OWNER_EMAIL"
  echo "Owner email set: $OWNER_EMAIL"
fi

echo "Done. Run: repokit --help"
