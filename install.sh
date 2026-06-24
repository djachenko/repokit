#!/bin/bash

set -e

REPO="djachenko/repokit"
VERSION=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" | sed 's|.*/||')
TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/repokit"

CURRENT=$(cat "$INSTALL_DIR/VERSION" 2> /dev/null || true)
if [[ "$CURRENT" == "$VERSION" ]]; then
  echo "Already up to date: repokit $VERSION"
  exit 0
fi

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
echo "$VERSION" > "$INSTALL_DIR/VERSION"
chmod +x "$INSTALL_DIR/repokit" "$INSTALL_DIR"/init/*.sh "$INSTALL_DIR"/hooks/*

if grep -q "# BEGIN repokit" "$SHELL_RC" 2> /dev/null; then
  sed -i '' '/# BEGIN repokit/,/# END repokit/d' "$SHELL_RC"
fi

cat >> "$SHELL_RC" << EOF
# BEGIN repokit
export PATH="$INSTALL_DIR:\$PATH"
repokit-update() {
  curl -fsSL https://raw.githubusercontent.com/djachenko/repokit/master/install.sh | bash
}
repokit-uninstall() {
  rm -rf "$INSTALL_DIR"
  git config --global --unset core.hooksPath 2>/dev/null || true
  sed -i '' '/# BEGIN repokit/,/# END repokit/d' "$SHELL_RC"
  echo "repokit uninstalled. Restart your shell."
}
# END repokit
EOF

echo "Added repokit to $SHELL_RC. Restart shell or: source $SHELL_RC"

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

echo "Done: repokit $VERSION"
echo "To update: repokit-update"
echo "To uninstall: repokit-uninstall"
