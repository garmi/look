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

Mac run flow:
1. In Xcode, select the LOOKPOC scheme.
2. Choose "My Mac (Designed for iPad/iPhone)" as the destination.
3. Press Cmd+R.

EOF
