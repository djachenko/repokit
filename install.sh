#!/bin/bash

set -e

REPO="djachenko/repokit"
# Follow the redirect from /releases/latest to get the tag name without hitting
# the GitHub API (which has rate limits and requires auth for higher limits).
VERSION=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" | sed 's|.*/||')
TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/repokit"

# Read the currently installed version (if any) to detect upgrade vs. fresh install.
CURRENT=$(cat "$INSTALL_DIR/VERSION" 2> /dev/null || true)
if [[ "$CURRENT" == "$VERSION" ]]; then
  echo "Already up to date: repokit $VERSION"
  exit 0
fi

# Detect the right rc file. Default to zsh; fall back to bash only if $SHELL says so.
SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && SHELL_RC="$HOME/.bashrc"

TMP=$(mktemp -d)
# Always clean up the temp dir on exit, even if a command fails (set -e).
trap 'rm -rf "$TMP"' EXIT

echo "Downloading repokit..."
curl -fsSL "$TARBALL_URL" | tar xz -C "$TMP"

echo "Installing to $INSTALL_DIR..."

# Replace the whole install dir atomically — no partial state if something fails mid-copy.
rm -rf "$INSTALL_DIR"
mv "$TMP"/repokit-"$VERSION" "$INSTALL_DIR"

# install.sh is a bootstrap — it has no purpose inside the installed tree.
rm -f "$INSTALL_DIR/install.sh"
# memory/ is a dev artifact; installed copies should not carry session state.
rm -rf "$INSTALL_DIR/memory"

echo "$VERSION" > "$INSTALL_DIR/VERSION"

# Make the orchestrator and all init scripts executable.
# Language setup scripts are called with `bash <script>` so they don't need +x.
chmod +x "$INSTALL_DIR/repokit" "$INSTALL_DIR"/init/*.sh "$INSTALL_DIR"/hooks/*

# ── Shell integration ─────────────────────────────────────────────────────────
#
# Old approach wrote a BEGIN/END block directly into .zshrc on every install,
# which was fragile: the END marker appeared inside the block (in sed/python
# patterns), so repeated installs corrupted the file.
#
# New approach: write integration to $INSTALL_DIR/shell.sh once, then add a
# single `source` line to the rc. On update, shell.sh is overwritten in-place —
# the rc line stays the same, no rc edits needed.

# Migrate: remove old-style BEGIN/END block if present.
# Using Python because BSD sed (macOS) and GNU sed handle -i differently.
python3 -c "
import re, pathlib
p = pathlib.Path('$SHELL_RC')
t = p.read_text()
t = re.sub(r'\n?# BEGIN repokit\n.*?# END repokit\n?', '', t, flags=re.DOTALL)
p.write_text(t)
" 2> /dev/null || true

# Write shell integration to its own file — never touch the rc again after this.
# Placeholders __INSTALL_DIR__ and __SHELL_RC__ are substituted by sed below
# because the heredoc uses single quotes ('SHELLEOF') to prevent premature
# expansion of $variables inside the script body.
cat > "$INSTALL_DIR/shell.sh" << 'SHELLEOF'
export PATH="__INSTALL_DIR__:$PATH"
repokit-update() {
  curl -fsSL https://raw.githubusercontent.com/djachenko/repokit/master/install.sh | bash
}
repokit-uninstall() {
  rm -rf "__INSTALL_DIR__"
  python3 -c "
import pathlib
p = pathlib.Path('__SHELL_RC__')
lines = p.read_text().splitlines(keepends=True)
lines = [l for l in lines if 'repokit/shell.sh' not in l]
p.write_text(''.join(lines))
" 2>/dev/null || true
  echo "repokit uninstalled. Restart your shell."
}
SHELLEOF

sed -i '' "s|__INSTALL_DIR__|$INSTALL_DIR|g; s|__SHELL_RC__|$SHELL_RC|g" "$INSTALL_DIR/shell.sh"

# Add source line to rc once — idempotent on updates since the line is identical.
python3 -c "
import pathlib
p = pathlib.Path('$SHELL_RC')
t = p.read_text()
line = '[ -f \"$INSTALL_DIR/shell.sh\" ] && source \"$INSTALL_DIR/shell.sh\"\n'
if line.strip() not in t:
    p.write_text(t.rstrip('\n') + '\n' + line)
" 2> /dev/null || true

echo "Added repokit to $SHELL_RC. Restart shell or: source $SHELL_RC"

if [[ -n "$CURRENT" ]]; then
  echo "Updated: repokit $CURRENT → $VERSION"
else
  echo "Installed: repokit $VERSION"
fi
echo "To update: repokit-update"
echo "To uninstall: repokit-uninstall"
