#!/usr/bin/env bash
# uninstall.sh — remove a self-hosted runner installed by install.sh.
#
# Usage:
#   ./uninstall.sh [--token REMOVAL_TOKEN] [--dir PATH]
#
# The removal token comes from:
#   GitHub → repo Settings → Actions → Runners → ⋯ on the runner → Remove
#   → "configure as a self-hosted runner: remove" → copy the token.
# Optional — if omitted, the runner is stopped + deleted locally but you'll
# need to remove it from the GitHub UI manually.

set -euo pipefail

TOKEN=""
INSTALL_DIR="${INSTALL_DIR:-$HOME/actions-runner}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token) TOKEN="$2";       shift 2 ;;
    --dir)   INSTALL_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--token REMOVAL_TOKEN] [--dir PATH]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "No runner at $INSTALL_DIR — nothing to uninstall."
  exit 0
fi

echo "→ Stopping runner service…"
sudo "$INSTALL_DIR/svc.sh" stop 2>/dev/null || true

echo "→ Uninstalling systemd service…"
sudo "$INSTALL_DIR/svc.sh" uninstall 2>/dev/null || true

if [[ -n "$TOKEN" ]] && [[ -f "$INSTALL_DIR/config.sh" ]]; then
  echo "→ Unregistering from GitHub…"
  "$INSTALL_DIR/config.sh" remove --token "$TOKEN" 2>/dev/null || \
    echo "   (couldn't unregister cleanly; delete the runner from the GitHub UI)"
fi

rm -rf "$INSTALL_DIR"
echo "✅ Runner removed from $INSTALL_DIR"
