#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$ROOT_DIR/logs"
CONFIG_DIR="$ROOT_DIR/config"
ASSETS_DIR="$ROOT_DIR/assets"

# === 1. Гарантируем права на запись ===
umask 002

# === 2. Настройки стрима ===
STREAM_RESTART_HOURS=${STREAM_RESTART_HOURS:-6}
if [ "$STREAM_RESTART_HOURS" -lt 1 ] || [ "$STREAM_RESTART_HOURS" -gt 12 ]; then
    STREAM_RESTART_HOURS=6
fi
STREAM_RESTART_INTERVAL=$((STREAM_RESTART_HOURS * 3600))

echo "$RTMP_URL" > "$CONFIG_DIR/rtmp_url.txt"

echo "🖥 Запуск Xvfb на DISPLAY=:0 (без UNIX-сокета)..."
Xvfb :0 -screen 0 1280x720x24 -nolisten tcp -nolisten unix -noreset +extension RANDR &
XVFB_PID=$!
export DISPLAY=:0
sleep 2

fluxbox >/dev/null 2>&1 &
FLUXBOX_PID=$!

echo "✅ Xvfb запущен на $DISPLAY"

start_stream_with_restart &
STREAM_MONITOR_PID=$!

# === 4. Wine prefix ===
WINEPREFIX="$CONFIG_DIR/wine_prefix"
if [ ! -d "$WINEPREFIX" ]; then
    echo "🍷 Инициализация Wine..."
    mkdir -p "$WINEPREFIX"
    env WINEPREFIX="$WINEPREFIX" wineboot --init
    sleep 5
fi

# === 5. Winetricks (только corefonts) ===
if [ ! -f "$WINEPREFIX/.winetricks_done" ]; then
    echo "📦 Установка corefonts..."
    winetricks -q corefonts
    touch "$WINEPREFIX/.winetricks_done"
fi

# === 6. Функции управления Roblox ===
is_roblox_running() {
    pgrep -f "RobloxPlayerLauncher.*" > /dev/null 2>&1
}

start_roblox() {
    echo "🤖 Запуск Chat Uses: Roblox Edition..."
    python3 "$ROOT_DIR/src/main.py"

    sleep 2

    if is_roblox_running; then
        echo "ℹ️ Roblox уже запущен."
        return 0
    fi

    ROBLOX_LAUNCHER="$ASSETS_DIR/RobloxPlayerLauncher.exe"
    if [ ! -f "$ROBLOX_LAUNCHER" ]; then
        echo "⚠️ RobloxPlayerLauncher.exe не найден."
        return 1
    fi

    echo "🎮 Запуск Roblox..."
    wine "$ROBLOX_LAUNCHER"

    sleep 2
    if is_roblox_running; then
        echo "✅ Roblox запущен."
    else
        echo "❌ Roblox не запустился. См. $ROBLOX_ERR_LOG"
    fi
}

stop_roblox() {
    if ! is_roblox_running; then
        return 0
    fi
    pkill -f "RobloxPlayerLauncher.*"
    sleep 3
    pkill -9 -f "RobloxPlayerLauncher.*" 2>/dev/null || true
    echo "⏹ Roblox остановлен."
}

# === 7. Запуск Roblox ===
start_roblox

# === 8. Монитор перезапуска стрима ===
start_stream_with_restart() {
    while true; do
        "$SCRIPT_DIR/stream_control.sh" start
        sleep $STREAM_RESTART_INTERVAL
        echo "🔄 Перезапуск стрима..."
        "$SCRIPT_DIR/stream_control.sh" restart
    done
}

# === 9. Основной цикл: запуск чат-бота ===


# === 10. Очистка при завершении ===
echo "🧹 Завершение всех процессов..."

# Остановка стрима
"$SCRIPT_DIR/stream_control.sh" stop

# Остановка Roblox
stop_roblox

# Остановка системных сервисов
kill $XVFB_PID $FLUXBOX_PID $STREAM_MONITOR_PID 2>/dev/null || true

echo "✅ Все процессы остановлены."
