#!/usr/bin/env bash
# Build KeyVoice.app and assemble a distributable disk image with a drag-to-Applications layout.
# Usage: ./Scripts/make-dmg.sh   →   build/KeyVoice.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

# 1. Build the signed .app (falls back to ad-hoc signing if no stable identity is set).
./Scripts/bundle.sh

APP="build/KeyVoice.app"
[ -d "$APP" ] || { echo "error: $APP not found — bundle.sh did not produce the app" >&2; exit 1; }

# 2. Stage the drag-install layout: KeyVoice.app + a symlink to /Applications.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/KeyVoice.app"
ln -s /Applications "$STAGE/Applications"

# 3. Compress into a read-only UDZO image.
DMG="build/KeyVoice.dmg"
rm -f "$DMG"
hdiutil create -volname "KeyVoice" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
echo "First launch on another Mac: right-click KeyVoice.app → Open → Open (the app is self-signed)."
