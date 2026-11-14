#!/bin/sh
# Removes shokz-aquavoice, both LaunchAgents, and the hidutil remap.
set -e

AGENTS_DIR="$HOME/Library/LaunchAgents"

launchctl unload "$AGENTS_DIR/com.shokz.aquavoice.plist" 2>/dev/null || true
launchctl unload "$AGENTS_DIR/com.shokz.playpause-block.plist" 2>/dev/null || true
rm -f "$AGENTS_DIR/com.shokz.aquavoice.plist" \
      "$AGENTS_DIR/com.shokz.playpause-block.plist" \
      "$HOME/.local/bin/shokz-aquavoice"

# restore the Loop120 Play/Pause key to macOS
/usr/bin/hidutil property --set '{"UserKeyMapping":[]}' || true

echo "uninstalled"
