#!/usr/bin/env bash
# Comandos de desenvolvimento. Uso: scripts/dev.sh <comando> [args]
#   build            compila o app (Debug)
#   test             roda os testes unitários
#   run              compila e abre o .app
#   open             abre o projeto no Xcode
#   clean            apaga build/
#   tv-info <ip>     GET /api/v2/ da TV (modelo, PowerState, MAC)
#   wake <mac>       Wake-on-LAN pela linha de comando
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=SamsungRemote.xcodeproj
SCHEME=SamsungRemote
DERIVED=build/DerivedData
APP="$DERIVED/Build/Products/Debug/SamsungRemote.app"

xcb() {
  local fmt=cat
  command -v xcbeautify >/dev/null && fmt=xcbeautify
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" "$@" | "$fmt"
}

cmd="${1:-help}"; shift || true
case "$cmd" in
  build)   xcb build ;;
  test)    xcb test ;;
  run)     xcb build && open "$APP" ;;
  open)    open "$PROJECT" ;;
  clean)   rm -rf build ;;
  tv-info) scripts/tv-info.sh "$@" ;;
  wake)    python3 scripts/wake.py "$@" ;;
  *)       sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
