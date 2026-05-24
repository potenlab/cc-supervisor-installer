#!/usr/bin/env bash
# Claude Code Supervisor — watcher uninstaller
set -euo pipefail

PLIST_PATH="$HOME/Library/LaunchAgents/com.cc-supervisor.watcher.plist"
LABEL="com.cc-supervisor.watcher"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST_PATH"
echo "✓ uninstalled launchd agent"
echo "  State in ~/.cc-supervisor retained. To wipe:"
echo "    rm -rf ~/.cc-supervisor"
