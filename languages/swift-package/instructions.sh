#!/bin/bash

# No secrets to add: the release runs on github.token. The first feat: commit
# merged to master releases 0.1.0.
echo ""
echo "→ Once released, add the package as a dependency with:"
echo "  .package(url: \"https://github.com/$OWNER/$REPO\", from: \"0.1.0\")"
