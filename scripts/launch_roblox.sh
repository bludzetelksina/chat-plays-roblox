#!/bin/bash
set -e

# --- Настройки ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
ASSETS_DIR="$ROOT_DIR/assets"
LOGS_DIR="$ROOT_DIR/logs"
WINEPREFIX="$ROOT_DIR/config/wine_prefix"

ROBLOX_EXE="$ASSETS_DIR/RobloxPlayer.exe"
LOG_FILE="$LOGS_DIR/roblox.log"

# --- Проверки ---
mkdir -p "$LOGS_DIR" "$WINEPREFIX"

if [ ! -f "$ROBLOX_EXE" ]; then
    echo "❌ Ошибка: $ROBLOX_EXE не найден. Поместите RobloxPlayer.exe в папку assets/."
    exit 1
fi

# Убедимся, что DISPLAY установлен (даже в Xvfb)
export DISPLAY=${DISPLAY:-:0}

# --- Запуск через nohup в фоне ---
echo "▶️ Запуск Roblox через Wine (фон)..."
nohup \
  env WINEPREFIX="$WINEPREFIX" \
  wine "$ROBLOX_EXE" \
  > "$LOG_FILE" 2>&1 &

ROBLOX_PID=$!

# Сохраняем PID для последующего управления (например, остановки)
echo $ROBLOX_PID > "$LOGS_DIR/roblox.pid"

echo "✅ Roblox запущен в фоне. PID: $ROBLOX_PID"
echo "📄 Лог: $LOG_FILE"
