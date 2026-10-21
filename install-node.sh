#!/usr/bin/env bash
# Quick launcher for install-node.sh from repo root
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/rathole-manager/rathole-manager/install-node.sh"
if [ ! -f "$TARGET" ]; then
    echo "Error: $TARGET not found." >&2
    exit 1
fi
cd "$SCRIPT_DIR/rathole-manager/rathole-manager"
exec bash "./install-node.sh" "$@"
