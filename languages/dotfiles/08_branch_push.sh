#!/bin/bash

bash "$SCRIPT_DIR/languages/$LANGUAGE/instructions.sh"

echo ""
echo "✓ Done: https://github.com/$OWNER/$REPO"

# -i.bak works on both BSD (macOS) and GNU sed; '' alone breaks on Linux.
sed -i.bak '/^base_branch=/d' .repokit && rm -f .repokit.bak
