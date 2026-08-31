#!/usr/bin/env bash
# Build KeyVoice and assemble a runnable .app bundle.
# TCC permissions (Input Monitoring, Accessibility, Microphone) need a real bundle, so a bare
# `swift run` binary isn't enough — this wraps the built executable into KeyVoice.app.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"

echo "Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/KeyVoice"
APP="build/KeyVoice.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/KeyVoice"
cp Packaging/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS gives the bundle a stable identity for TCC grants (fine for personal use).
codesign --force --deep --sign - "$APP"

echo "Built $APP"
echo "Run it:  open $APP     (then grant Input Monitoring + Accessibility + Microphone in System Settings)"
