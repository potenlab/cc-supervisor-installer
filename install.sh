#!/usr/bin/env bash
# Claude Code Supervisor — watcher installer
#
# Usage (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/potenlab/cc-supervisor-installer/main/install.sh | INGEST_TOKEN=... bash
#
# Or after cloning:
#   INGEST_TOKEN=... ./install.sh
#
# What this does:
#   1. Downloads the signed watcher binary from this repo
#   2. Verifies sha256 checksum
#   3. Generates ~/.cc-supervisor/watcher.env if missing
#   4. Installs a launchd agent at ~/Library/LaunchAgents/com.cc-supervisor.watcher.plist
#
# What it ships to the server (only when an allowed company account is active):
#   - Prompt previews (≤500 chars), token usage, model, project path
#   - /usage utilization for that account
# Personal accounts → ingest paused automatically.

set -euo pipefail

BASE_URL="${CC_SUPERVISOR_INSTALLER_URL:-https://raw.githubusercontent.com/potenlab/cc-supervisor-installer/main}"
DASHBOARD_URL="${CC_SUPERVISOR_DASHBOARD_URL:-https://claude-code-supervisor.vercel.app}"
# Baked-in ingest token. Server still gates by claude_accounts.is_company → a
# leaked token can't ship anything from a non-company Anthropic login.
: "${INGEST_TOKEN:=f8d22691b4a8022ebf3b8dc134622214fc3366a2bb8ca8af}"
INSTALL_DIR="$HOME/.cc-supervisor"
BIN_PATH="$INSTALL_DIR/cc-supervisor-watcher.js"
LOG_PATH="$INSTALL_DIR/watcher.log"
ENV_PATH="$INSTALL_DIR/watcher.env"
PLIST_PATH="$HOME/Library/LaunchAgents/com.cc-supervisor.watcher.plist"
LABEL="com.cc-supervisor.watcher"

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
blue()   { printf "\033[34m%s\033[0m\n" "$*"; }
hr()     { printf "\033[2m%s\033[0m\n" "──────────────────────────────────────────"; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    red "Missing required command: $1"
    [[ "$1" == "node" ]] && red "  Install Node.js 22+: https://nodejs.org/"
    exit 1
  fi
}

blue "▸ checking prerequisites…"
[[ "$(uname -s)" == "Darwin" ]] || { red "Only macOS is supported."; exit 1; }
require node
require shasum
require curl
require launchctl
NODE_VERSION=$(node -p 'process.versions.node.split(".").map(Number)[0]')
if (( NODE_VERSION < 22 )); then
  red "Node $NODE_VERSION too old. Need 22+."
  exit 1
fi
mkdir -p "$INSTALL_DIR"
green "  ok"

blue "▸ downloading watcher…"
TMP_BIN=$(mktemp)
TMP_SHA=$(mktemp)
TMP_VERSION=$(mktemp)
trap 'rm -f "$TMP_BIN" "$TMP_SHA" "$TMP_VERSION"' EXIT
curl -fsSL "$BASE_URL/cc-supervisor-watcher.js" -o "$TMP_BIN"
curl -fsSL "$BASE_URL/cc-supervisor-watcher.sha256" -o "$TMP_SHA"
curl -fsSL "$BASE_URL/cc-supervisor-watcher.version" -o "$TMP_VERSION" || echo "?" > "$TMP_VERSION"
EXPECTED_SHA=$(tr -d '[:space:]' < "$TMP_SHA")
ACTUAL_SHA=$(shasum -a 256 "$TMP_BIN" | awk '{print $1}')
if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
  red "Checksum mismatch — refusing to install."
  red "  expected: $EXPECTED_SHA"
  red "  actual:   $ACTUAL_SHA"
  exit 1
fi
VERSION=$(tr -d '[:space:]' < "$TMP_VERSION")
green "  ok · v$VERSION · sha=${ACTUAL_SHA:0:12}…"

mv "$TMP_BIN" "$BIN_PATH"
chmod +x "$BIN_PATH"

cat > "$ENV_PATH" <<EOF
INGEST_URL=$DASHBOARD_URL/api/ingest
CONFIG_URL=$DASHBOARD_URL/api/config
INGEST_TOKEN=$INGEST_TOKEN
EOF
chmod 600 "$ENV_PATH"

NODE_BIN=$(command -v node)
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_BIN</string>
    <string>$BIN_PATH</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOG_PATH</string>
  <key>StandardErrorPath</key><string>$LOG_PATH</string>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"

hr
green "✓ installed"
echo "  log: $LOG_PATH"
hr
echo
echo "▸ tail the log to confirm:"
echo "    tail -f $LOG_PATH"
echo
echo "▸ to update later:"
echo "    curl -fsSL $BASE_URL/install.sh | bash"
echo
echo "▸ to uninstall:"
echo "    curl -fsSL $BASE_URL/uninstall.sh | bash"
