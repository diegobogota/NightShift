#!/bin/bash
# Compila NightShift.app
# Autor: Diego Bogotá Linares — https://diegobogota.com
#
# Uso:
#   ./build.sh            # genera build/NightShift.app
#   ./build.sh --install  # además la copia a ~/Applications
set -euo pipefail

cd "$(dirname "$0")"

APP="build/NightShift.app"
ARCH="$(uname -m)"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ Compilando ($ARCH)…"
swiftc -O \
  -target "${ARCH}-apple-macos13.0" \
  -framework AppKit -framework IOKit \
  Sources/main.swift \
  -o "$APP/Contents/MacOS/NightShift"

cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "→ Firmando (ad hoc)…"
codesign --force --sign - "$APP"

echo "✓ Listo: $APP"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/NightShift.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "✓ Instalada en ~/Applications/NightShift.app"
fi
