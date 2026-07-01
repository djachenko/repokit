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
rm -rf "$INSTALL_DIR/memory"
echo "$VERSION" > "$INSTALL_DIR/VERSION"
chmod +x "$INSTALL_DIR/repokit" "$INSTALL_DIR"/init/*.sh "$INSTALL_DIR"/hooks/*

python3 -c "
import re, pathlib
p = pathlib.Path('$SHELL_RC')
t = p.read_text()
t = re.sub(r'\n?# BEGIN repokit\n.*?# END repokit\n?', '', t, flags=re.DOTALL)
p.write_text(t)
" 2> /dev/null || true

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

if [[ -n "$CURRENT" ]]; then
  echo "Updated: repokit $CURRENT → $VERSION"
else
  echo "Installed: repokit $VERSION"
fi
echo "To update: repokit-update"
echo "To uninstall: repokit-uninstall"
