#!/usr/bin/env bash
# Compile KeyVoice's Metal shaders into a metallib resource.
# SwiftPM does not compile .metal files itself (Xcode does), so we precompile here; the metallib is
# loaded at runtime via SwiftUI's ShaderLibrary(url:). Re-run this whenever a .metal file changes —
# Scripts/bundle.sh also runs it before packaging.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="Sources/KeyVoiceHUD/Shaders/Aurora.metal"
OUT="Sources/KeyVoiceHUD/Resources/default.metallib"
mkdir -p "$(dirname "$OUT")"

AIR="$(mktemp -t aurora)".air
xcrun -sdk macosx metal -c "$SRC" -o "$AIR"
xcrun -sdk macosx metallib "$AIR" -o "$OUT"
rm -f "$AIR"
echo "Built $OUT"
