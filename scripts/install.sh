#!/usr/bin/env bash
# install.sh — one-shot install of a self-hosted GitHub Actions runner.
#
# Designed to run on a fresh Ubuntu / Debian box (e.g. an EC2 instance you
# already use to host the app you're deploying). After this script finishes,
# the runner is registered to your repo, configured as a systemd service,
# survives reboots, and shows up under repo Settings → Actions → Runners.
#
# Usage:
#   ./install.sh --repo OWNER/REPO --token REGISTRATION_TOKEN [--name NAME] [--labels CSV]
#
# Get the registration token from:
#   GitHub → repo Settings → Actions → Runners → New self-hosted runner
#   (the token is one-time and expires in ~1 hour)
#
# Idempotent: re-running uninstalls the previous instance first.

set -euo pipefail

# ---------- args ----------

REPO=""
TOKEN=""
RUNNER_NAME="$(hostname)-runner"
RUNNER_LABELS="self-hosted,linux,x64"
RUNNER_VERSION="${RUNNER_VERSION:-2.319.1}"  # bump as needed
INSTALL_DIR="${INSTALL_DIR:-$HOME/actions-runner}"

usage() {
  cat <<EOF
Usage: $0 --repo OWNER/REPO --token TOKEN [options]

Required:
  --repo OWNER/REPO      e.g. jatinbodra/BookdAI
  --token TOKEN          one-time registration token from repo settings

Optional:
  --name NAME            display name shown in GitHub UI (default: <hostname>-runner)
  --labels "a,b,c"       comma-separated labels (default: self-hosted,linux,x64)
  --version X.Y.Z        runner binary version (default: $RUNNER_VERSION)
  --dir PATH             install dir (default: \$HOME/actions-runner)
  -h, --help             show this help

Example:
  $0 --repo jatinbodra/BookdAI --token A1B2C3...
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO="$2";          shift 2 ;;
    --token)   TOKEN="$2";         shift 2 ;;
    --name)    RUNNER_NAME="$2";   shift 2 ;;
    --labels)  RUNNER_LABELS="$2"; shift 2 ;;
    --version) RUNNER_VERSION="$2";shift 2 ;;
    --dir)     INSTALL_DIR="$2";   shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

[[ -z "$REPO"  ]] && { echo "ERROR: --repo is required";  usage; }
[[ -z "$TOKEN" ]] && { echo "ERROR: --token is required"; usage; }

# ---------- preflight ----------

echo ""
echo "════════════════════════════════════════════════════"
echo " Self-hosted GitHub Actions runner — installer"
echo "════════════════════════════════════════════════════"
echo " Repo:      $REPO"
echo " Name:      $RUNNER_NAME"
echo " Labels:    $RUNNER_LABELS"
echo " Version:   $RUNNER_VERSION"
echo " Install:   $INSTALL_DIR"
echo "════════════════════════════════════════════════════"
echo ""

# Detect OS — we explicitly support Linux x64. macOS / Windows / ARM users can
# adapt by pointing --version at a different release asset.
if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
  echo "WARN: this script targets Linux x86_64; you're on $(uname -s)/$(uname -m)."
  echo "      Continuing, but you may need to override --version with the right asset."
fi

# Required tools.
for cmd in curl tar sudo systemctl; do
  command -v "$cmd" >/dev/null || { echo "ERROR: '$cmd' not found in PATH"; exit 1; }
done

# Tear down a prior installation so re-runs are idempotent.
if [[ -d "$INSTALL_DIR" ]]; then
  echo "→ Existing runner found at $INSTALL_DIR — uninstalling first."
  if [[ -f "$INSTALL_DIR/svc.sh" ]]; then
    sudo "$INSTALL_DIR/svc.sh" stop      2>/dev/null || true
    sudo "$INSTALL_DIR/svc.sh" uninstall 2>/dev/null || true
  fi
  # Best-effort GitHub-side unregister (needs a *removal* token; if it fails,
  # the user can delete the stale runner from the UI).
  if [[ -f "$INSTALL_DIR/config.sh" ]]; then
    "$INSTALL_DIR/config.sh" remove --token "$TOKEN" 2>/dev/null || true
  fi
  rm -rf "$INSTALL_DIR"
fi

# ---------- install ----------

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "→ Downloading runner v$RUNNER_VERSION…"
TARBALL="actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"
curl -fsSL -o "$TARBALL" \
  "https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/$TARBALL"

echo "→ Extracting…"
tar xzf "$TARBALL"
rm -f "$TARBALL"

echo "→ Configuring against repo $REPO…"
./config.sh \
  --url "https://github.com/$REPO" \
  --token "$TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --work "_work" \
  --unattended \
  --replace

echo "→ Installing as systemd service…"
sudo ./svc.sh install "${SUDO_USER:-$(whoami)}"
sudo ./svc.sh start

echo ""
echo "════════════════════════════════════════════════════"
echo " ✅ Runner installed and running"
echo "════════════════════════════════════════════════════"
echo " Verify:"
echo "   sudo $INSTALL_DIR/svc.sh status"
echo "   https://github.com/$REPO/settings/actions/runners"
echo ""
echo " Next step — in your workflow YAML:"
echo "   jobs:"
echo "     deploy:"
echo "       runs-on: self-hosted"
echo "════════════════════════════════════════════════════"
