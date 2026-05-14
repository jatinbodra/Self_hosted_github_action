#!/usr/bin/env bash
# status.sh — show what the locally-installed runner is doing.
#
# Prints: service state, last 30 log lines, what job (if any) is in-flight.

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/actions-runner}"

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "No runner at $INSTALL_DIR. Run install.sh first."
  exit 1
fi

echo "════════════════════════════════════════════════════"
echo " Runner status — $INSTALL_DIR"
echo "════════════════════════════════════════════════════"
sudo "$INSTALL_DIR/svc.sh" status 2>&1 | head -20
echo ""
echo "── Recent log (last 30 lines) ─────────────────────"
sudo journalctl -u "actions.runner.$(basename "$(cat "$INSTALL_DIR/.runner" 2>/dev/null | grep -o '"agentName": *"[^"]*"' | head -1 | cut -d'"' -f4)").service" \
  -n 30 --no-pager 2>/dev/null \
  || echo "(no journal entries — service may not be running)"
