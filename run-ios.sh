#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it with: brew install xcodegen"
  exit 1
fi

echo "Generating Xcode project..."
xcodegen generate

echo "Opening LOOKPOC.xcodeproj..."
open LOOKPOC.xcodeproj

cat <<'EOF'

Next steps in Xcode:
1. Select the LOOKPOC scheme.
2. Pick either "My Mac (Designed for iPad/iPhone)" or your connected iPhone.
3. Press Cmd+R to run.

EOF
