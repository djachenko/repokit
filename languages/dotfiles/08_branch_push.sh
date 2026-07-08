#!/bin/bash

bash "$SCRIPT_DIR/languages/$LANGUAGE/instructions.sh"

echo ""
echo "✓ Done: https://github.com/$OWNER/$REPO"

sed -i '' '/^base_branch=/d' .repokit
