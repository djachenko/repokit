#!/bin/bash

set -e

REPO="djachenko/repokit"
# Follow the redirect from /releases/latest to get the tag name without hitting
# the GitHub API (which has rate limits and requires auth for higher limits).
LATEST_URL=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") ||
  {
    echo "✗ Failed to reach GitHub" >&2
    exit 1
  }
# ##*/ strips everything up to the last slash — the tag is the final path segment.
VERSION="${LATEST_URL##*/}"
[[ -n "$VERSION" ]] || {
  echo "✗ Could not detect latest version" >&2
  exit 1
}
TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/repokit"

# Detect OS and CPU arch for the prebuilt binary asset.
# uname -s → Darwin/Linux; uname -m reports the CPU under several names, so
# normalise to Go's GOARCH spelling: Intel is x86_64 everywhere, ARM64 is
# arm64 on macOS but aarch64 on Linux.
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
[[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
[[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
BIN_URL="https://github.com/$REPO/releases/download/$VERSION/repokore-${OS}-${ARCH}"

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

# Fetch the binary while the existing install is still untouched — a missing
# asset is then discovered before the point of no return, not after it.
# curl leaves a partial file behind on failure, so drop it and let the presence
# of $TMP/repokore be the single check further down.
echo "Downloading repokore..."
if ! curl -fsSL "$BIN_URL" -o "$TMP/repokore" 2> /dev/null; then
  rm -f "$TMP/repokore"
  echo "⚠ Could not download repokore for ${OS}/${ARCH} — smart-merge of pyproject.toml will be unavailable"
fi

echo "Installing to $INSTALL_DIR..."

# Move old install dir aside so we can restore it if the new install fails.
BAK="$INSTALL_DIR.bak"
rm -rf "$BAK"
[[ -d "$INSTALL_DIR" ]] && mv "$INSTALL_DIR" "$BAK"
mv "$TMP"/repokit-"$VERSION" "$INSTALL_DIR" || {
  echo "✗ Install failed" >&2
  [[ -d "$BAK" ]] && mv "$BAK" "$INSTALL_DIR"
  exit 1
}
rm -rf "$BAK"

# install.sh is a bootstrap — it has no purpose inside the installed tree.
rm -f "$INSTALL_DIR/install.sh"
# memory/ is a dev artifact; installed copies should not carry session state.
rm -rf "$INSTALL_DIR/memory"

echo "$VERSION" > "$INSTALL_DIR/VERSION"

# Make the orchestrator and all init scripts executable.
# Language setup scripts are called with `bash <script>` so they don't need +x.
chmod +x "$INSTALL_DIR/repokit" "$INSTALL_DIR"/init/*.sh "$INSTALL_DIR"/hooks/*

# Put the binary downloaded above in place. Absent means the download failed and
# already warned; the rest of repokit works, only smart-merge is unavailable.
if [[ -f "$TMP/repokore" ]]; then
  mkdir -p "$INSTALL_DIR/bin"
  mv "$TMP/repokore" "$INSTALL_DIR/bin/repokore"
  chmod +x "$INSTALL_DIR/bin/repokore"
fi

# ── Shell integration ─────────────────────────────────────────────────────────
#
# Old approach wrote a BEGIN/END block directly into .zshrc on every install,
# which was fragile: the END marker appeared inside the block (in the editing
# patterns themselves), so repeated installs corrupted the file.
#
# New approach: write integration to $INSTALL_DIR/shell.sh once, then add a
# single `source` line to the rc. On update, shell.sh is overwritten in-place —
# the rc line stays the same, no rc edits needed.

# Write shell integration to its own file — never touch the rc again after this.
# The heredoc delimiter is unquoted, so $INSTALL_DIR and $SHELL_RC expand while
# writing; \$PATH is escaped to stay literal and be resolved at shell startup.
cat > "$INSTALL_DIR/shell.sh" << SHELLEOF
export PATH="$INSTALL_DIR:\$PATH"
repokit-update() {
  curl -fsSL https://raw.githubusercontent.com/djachenko/repokit/master/install.sh | bash
}
repokit-uninstall() {
  rm -rf "$INSTALL_DIR"
  # grep -vF matches a fixed string, so nothing in the path needs escaping.
  # || true keeps an empty result from aborting the function under set -e.
  { grep -vF 'repokit/shell.sh' "$SHELL_RC" || true; } > "$SHELL_RC.tmp"
  mv "$SHELL_RC.tmp" "$SHELL_RC"
  echo "repokit uninstalled. Restart your shell."
}
SHELLEOF

# Migrate: remove old-style BEGIN/END block if present.
# sed -i.bak works on both macOS (BSD sed) and Linux (GNU sed).
if grep -q '# BEGIN repokit' "$SHELL_RC" 2> /dev/null; then
  sed -i.bak '/# BEGIN repokit/,/# END repokit/d' "$SHELL_RC"
  rm -f "${SHELL_RC}.bak"
fi

# Add source line to rc once — idempotent on updates since the line is identical.
SOURCE_LINE="[ -f \"$INSTALL_DIR/shell.sh\" ] && source \"$INSTALL_DIR/shell.sh\""
if ! grep -qF "$SOURCE_LINE" "$SHELL_RC" 2> /dev/null; then
  printf '\n%s\n' "$SOURCE_LINE" >> "$SHELL_RC"
fi
echo "Added repokit to $SHELL_RC. Restart shell or: source $SHELL_RC"

if [[ -n "$CURRENT" ]]; then
  echo "Updated: repokit $CURRENT → $VERSION"
else
  echo "Installed: repokit $VERSION"
fi
echo "To update: repokit-update"
echo "To uninstall: repokit-uninstall"
