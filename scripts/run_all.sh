#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$ROOT_DIR/logs"
CONFIG_DIR="$ROOT_DIR/config"

mkdir -p "$LOGS_DIR"

# === Настройки автоперезапуска стрима ===
# Интервал в часах (минимум 1, максимум 12)
STREAM_RESTART_HOURS=${STREAM_RESTART_HOURS:-6}
if [ "$STREAM_RESTART_HOURS" -lt 1 ] || [ "$STREAM_RESTART_HOURS" -gt 12 ]; then
    echo "⚠️ Некорректный STREAM_RESTART_HOURS. Используется 6."
    STREAM_RESTART_HOURS=6
fi
STREAM_RESTART_INTERVAL=$((STREAM_RESTART_HOURS * 3600))  # секунды

# === 1. Запуск Xvfb и Fluxbox ===
echo "🖥 Запуск Xvfb на :0..."
Xvfb :0 -screen 0 1280x720x24 -nolisten tcp -dpi 96 &
XVFB_PID=$!
export DISPLAY=:0

fluxbox >/dev/null 2>&1 &
FLUXBOX_PID=$!

# === 2. Инициализация Wine (если нужно) ===
WINEPREFIX="$CONFIG_DIR/wine_prefix"
if [ ! -d "$WINEPREFIX" ]; then
    echo "🍷 Инициализация Wine prefix..."
    mkdir -p "$WINEPREFIX"
    env WINEPREFIX="$WINEPREFIX" wineboot --init
    sleep 5
fi

# === 3. Запуск Roblox ===
if [ -f "$ROOT_DIR/assets/RobloxPlayer.exe" ]; then
    echo "🎮 Запуск Roblox..."
    nohup env WINEPREFIX="$WINEPREFIX" wine "$ROOT_DIR/assets/RobloxPlayer.exe" \
        >/dev/null 2>"$LOGS_DIR/roblox_stderr.log" &
    ROBLOX_PID=$!
    echo $ROBLOX_PID > "$LOGS_DIR/roblox.pid"
else
    echo "⚠️ RobloxPlayer.exe не найден. Пропуск запуска игры."
fi

# === 4. Фоновый монитор перезапуска стрима ===
start_stream_with_restart() {
    echo "🔁 Стрим будет автоматически перезапускаться каждые ${STREAM_RESTART_HOURS} часов."

    while true; do
        # Запуск стрима
        "$SCRIPT_DIR/stream_control.sh" start

        # Ждём интервал
        sleep $STREAM_RESTART_INTERVAL

        # Перезапуск
        echo "🔄 Автоматический перезапуск стрима..."
        "$SCRIPT_DIR/stream_control.sh" restart
    done
}

# Запускаем монитор в фоне
start_stream_with_restart &
STREAM_MONITOR_PID=$!

# === 5. Запуск чат-бота ===
echo "🤖 Запуск Chat Uses: Roblox Edition..."
python3 "$ROOT_DIR/src/main.py"

# === 6. Очистка при завершении ===
echo "🧹 Завершение всех процессов..."
kill $XVFB_PID $FLUXBOX_PID $STREAM_MONITOR_PID 2>/dev/null || true

if [ -f "$LOGS_DIR/roblox.pid" ]; then
    ROBLOX_PID=$(cat "$LOGS_DIR/roblox.pid")
    kill $ROBLOX_PID 2>/dev/null || true
    rm -f "$LOGS_DIR/roblox.pid"
fi

# Остановка стрима
"$SCRIPT_DIR/stream_control.sh" stop
