#!/bin/sh
# shokz-aquavoice installer
# Builds the daemon, installs it to ~/.local/bin, registers LaunchAgents,
# and applies the Loop120-specific Play/Pause block (hidutil).
#
# Usage:
#   ./install.sh
#   SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./install.sh
#
# SIGN_IDENTITY: code-signing identity passed to `codesign -s`.
#   Default "-" = ad hoc. With ad hoc signing, macOS TCC permissions
#   (Input Monitoring / Accessibility) are bound to the build's cdhash,
#   so you must re-grant them after every rebuild.
#   Using your Apple Development certificate keeps grants across rebuilds.

set -e
cd "$(dirname "$0")"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
AGENTS_DIR="$HOME/Library/LaunchAgents"
BIN="$INSTALL_DIR/shokz-aquavoice"

echo "==> Building shokz-aquavoice"
swiftc main.swift -o shokz-aquavoice -framework CoreGraphics -framework IOKit

echo "==> Signing (identity: $SIGN_IDENTITY)"
codesign -s "$SIGN_IDENTITY" -f shokz-aquavoice

mkdir -p "$INSTALL_DIR"
cp shokz-aquavoice "$BIN"
rm shokz-aquavoice
echo "    installed: $BIN"

echo "==> Installing LaunchAgents"
sed "s|__HOME__|$HOME|g" launchagents/com.shokz.aquavoice.plist \
  > "$AGENTS_DIR/com.shokz.aquavoice.plist"
cp launchagents/com.shokz.playpause-block.plist "$AGENTS_DIR/"

launchctl unload "$AGENTS_DIR/com.shokz.aquavoice.plist" 2>/dev/null || true
launchctl load -w "$AGENTS_DIR/com.shokz.aquavoice.plist"
launchctl unload "$AGENTS_DIR/com.shokz.playpause-block.plist" 2>/dev/null || true
launchctl load -w "$AGENTS_DIR/com.shokz.playpause-block.plist"

echo "==> Applying Loop120 Play/Pause block (hidutil)"
/usr/bin/hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":51539607757,"HIDKeyboardModifierMappingDst":1095216660480,"VendorID":13585,"ProductID":12038,"DeviceUsagePage":12,"DeviceUsage":1}]}'

cat <<'EOF'

Done. Grant the daemon its permissions once:

  System Settings -> Privacy & Security
    - Input Monitoring   -> add/enable shokz-aquavoice
    - Accessibility      -> add/enable shokz-aquavoice
      (on recent macOS this pane is named
       "デバイスの制御とデータのアクセス")

Then press the headset button: Aqua Voice should start.
Logs: /tmp/shokz-aquavoice.log
EOF
