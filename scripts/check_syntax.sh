#!/usr/bin/env bash
set -euo pipefail

echo "=== Checking root scripts ==="
for f in bootstrap.sh install.sh install-node.sh install-panel.sh; do
  if [ -f "$f" ]; then
    bash -n "$f"
    echo "$f: OK"
  fi
done

echo "=== Checking package scripts and CLIs ==="
cd rathole-manager/rathole-manager
for f in *.sh ratholectl ratholenode; do
  if [ -f "$f" ]; then
    bash -n "$f"
    echo "$f: OK"
  fi
done
echo "All scripts passed syntax check!"
