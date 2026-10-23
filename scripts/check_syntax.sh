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

if command -v shellcheck >/dev/null 2>&1; then
  echo "=== Running ShellCheck on root scripts ==="
  (cd ../.. && shellcheck -S warning -e SC1090,SC1091,SC2034,SC2154 bootstrap.sh install.sh install-node.sh install-panel.sh)
  echo "=== Running ShellCheck on package scripts ==="
  shellcheck -S warning -e SC1090,SC1091,SC2034,SC2154 common.sh update.sh install-node.sh install-panel.sh ratholectl ratholenode
  echo "ShellCheck passed successfully!"
else
  echo "shellcheck not installed, skipping shellcheck stage (bash -n verified)."
fi
