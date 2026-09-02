#!/usr/bin/env bash
# Build KeyVoice and assemble a runnable .app bundle.
# TCC permissions (Input Monitoring, Accessibility, Microphone) need a real bundle, so a bare
# `swift run` binary isn't enough — this wraps the built executable into KeyVoice.app.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"

echo "Compiling shaders…"
./Scripts/build-shaders.sh

echo "Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/KeyVoice"
APP="build/KeyVoice.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/KeyVoice"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# --- Code signing -----------------------------------------------------------------------------
# macOS ties TCC permissions (Input Monitoring, Accessibility) to the app's code-signing identity.
# A real CERTIFICATE anchors the "designated requirement" to the cert, so the identity — and the
# permissions you granted — stay stable across rebuilds. AD-HOC signing (`codesign -s -`) anchors it
# to the executable's CDHash, which changes on every rebuild, so macOS drops the grants each time.
#
# Identity resolution (configurable — nothing hardcoded):
#   1. $KEYVOICE_CODESIGN_IDENTITY, if set (an Apple Development cert, or the self-signed one from
#      Scripts/setup-signing.sh).
#   2. otherwise, auto-detect an installed "Apple Development" identity.
#   3. otherwise, warn loudly and fall back to ad-hoc (grants will reset on every rebuild).
IDENTITY="${KEYVOICE_CODESIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
              | grep -o '"Apple Development:[^"]*"' | head -1 | tr -d '"')" || true
fi

if [ -n "$IDENTITY" ]; then
  echo "Signing with stable identity: $IDENTITY"
  codesign --force --sign "$IDENTITY" "$APP"
else
  {
    echo
    echo "WARNING: no stable code-signing identity found — falling back to AD-HOC signing."
    echo "         macOS will DROP KeyVoice's Input Monitoring & Accessibility grants on every"
    echo "         rebuild, so the hotkey won't arm after a rebuild until you re-grant them."
    echo "         Fix once:  ./Scripts/setup-signing.sh   (then export the identity it prints),"
    echo "         or set KEYVOICE_CODESIGN_IDENTITY to an Apple Development certificate."
    echo "         See README.md > \"Code signing\"."
    echo
  } >&2
  codesign --force --sign - "$APP"
fi

echo "Designated requirement (stable across rebuilds only if certificate-based):"
codesign -d -r- "$APP" 2>&1 | sed -n 's/^designated => /  /p'

echo "Built $APP"
echo "Run it:  open $APP     (grant Input Monitoring + Accessibility + Microphone on first launch)"
