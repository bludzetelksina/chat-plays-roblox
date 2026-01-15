#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
ASSETS_DIR="$ROOT_DIR/assets"
LOGS_DIR="$ROOT_DIR/logs"
WINEPREFIX="$ROOT_DIR/config/wine_prefix"

mkdir -p "$LOGS_DIR"

LAUNCHER="$ASSETS_DIR/RobloxPlayerLauncher.exe"
PLACE_ID="${1:-1}"  # по умолчанию — главный экран

if [ ! -f "$LAUNCHER" ]; then
    echo "❌ RobloxPlayerLauncher.exe не найден в assets/"
    exit 1
fi

export DISPLAY=${DISPLAY:-:0}

echo "🎮 Запуск Roblox (PlaceId: $PLACE_ID)..."
nohup env WINEPREFIX="$WINEPREFIX" \
  wine "$LAUNCHER" --app Play --args "placeId=$PLACE_ID" \
  > "$LOGS_DIR/roblox.log" 2>&1 &

echo $! > "$LOGS_DIR/roblox.pid"
echo "✅ Запущено (PID: $(cat "$LOGS_DIR/roblox.pid"))"
