#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$ROOT_DIR/logs"
CONFIG_DIR="$ROOT_DIR/config"
ASSETS_DIR="$ROOT_DIR/assets"

# === 1. Гарантируем создание логов Roblox ===
mkdir -p "$LOGS_DIR" "$CONFIG_DIR"
ROBLOX_LOG="$LOGS_DIR/roblox.log"
ROBLOX_ERR_LOG="$LOGS_DIR/roblox_stderr.log"

echo "📝 Логи Roblox готовы: $ROBLOX_LOG, $ROBLOX_ERR_LOG"


# === 2. Настройки автоперезапуска стрима ===
STREAM_RESTART_HOURS=${STREAM_RESTART_HOURS:-6}
if [ "$STREAM_RESTART_HOURS" -lt 1 ] || [ "$STREAM_RESTART_HOURS" -gt 12 ]; then
    STREAM_RESTART_HOURS=6
fi
STREAM_RESTART_INTERVAL=$((STREAM_RESTART_HOURS * 3600))

# === 3. Очистка старых X11-локов и запуск Xvfb ===
echo "🧹 Очистка старых X11-локов..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true

echo "🖥 Запуск Xvfb на DISPLAY=:0..."
Xvfb :0 -screen 0 1280x720x24 -nolisten tcp -nolisten unix +extension RANDR &
XVFB_PID=$!
export DISPLAY=:0

# Ждём, пока Xvfb инициализируется
sleep 2

fluxbox >/dev/null 2>&1 &
FLUXBOX_PID=$!

# === 4. Инициализация Wine ===
WINEPREFIX="$CONFIG_DIR/wine_prefix"
if [ ! -d "$WINEPREFIX" ]; then
    echo "🍷 Инициализация Wine prefix..."
    mkdir -p "$WINEPREFIX"
    env WINEPREFIX="$WINEPREFIX" wineboot --init
    sleep 5
fi

# === 5. Функции управления Roblox (без PID-файла) ===

is_roblox_running() {
    pgrep -f "wine.*RobloxPlayer.*--app Play" > /dev/null 2>&1
}

get_roblox_pid() {
    pgrep -f "wine.*RobloxPlayer.*--app Play" 2>/dev/null | head -n1
}

start_roblox() {
    if is_roblox_running; then
        echo "ℹ️ Roblox уже запущен (PID: $(get_roblox_pid))."
        return 0
    fi

    ROBLOX_LAUNCHER="$ASSETS_DIR/RobloxPlayer.exe"
    if [ ! -f "$ROBLOX_LAUNCHER" ]; then
        echo "⚠️ RobloxPlayerLauncher.exe не найден. Пропуск запуска."
        return 1
    fi

    echo "🎮 Запуск Roblox..."
    nohup env WINEPREFIX="$WINEPREFIX" \
        wine "$ROBLOX_LAUNCHER" --app Play --args "placeId=0" \
        > "$ROBLOX_LOG" 2>"$ROBLOX_ERR_LOG" &
    
    # Ждём, чтобы убедиться, что процесс стартовал
    sleep 2
    if is_roblox_running; then
        echo "✅ Roblox запущен. PID: $(get_roblox_pid)"
    else
        echo "❌ Не удалось запустить Roblox. См. логи."
    fi
}

stop_roblox() {
    if ! is_roblox_running; then
        echo "ℹ️ Roblox не запущен."
        return 0
    fi

    PID=$(get_roblox_pid)
    echo "⏹ Остановка Roblox (PID: $PID)..."
    kill "$PID" 2>/dev/null || true
    sleep 3
    if kill -0 "$PID" 2>/dev/null; then
        echo "⚠️ Принудительное завершение..."
        kill -9 "$PID" 2>/dev/null || true
    fi
    echo "✅ Roblox остановлен."
}

# === 6. Запуск Roblox (если файл существует) ===
start_roblox

# === 7. Фоновый монитор перезапуска стрима ===
start_stream_with_restart() {
    while true; do
        "$SCRIPT_DIR/stream_control.sh" start
        sleep $STREAM_RESTART_INTERVAL
        echo "🔄 Перезапуск стрима..."
        "$SCRIPT_DIR/stream_control.sh" restart
    done
}

start_stream_with_restart &
STREAM_MONITOR_PID=$!

# === 8. Запуск чат-бота ===
echo "🤖 Запуск Chat Uses: Roblox Edition..."
python3 "$ROOT_DIR/src/main.py"

# === 9. Очистка при завершении ===
echo "🧹 Завершение всех процессов..."

# Остановка стрима
"$SCRIPT_DIR/stream_control.sh" stop

# Остановка Roblox
stop_roblox

# Остановка системных сервисов
kill $XVFB_PID $FLUXBOX_PID $STREAM_MONITOR_PID 2>/dev/null || true

echo "✅ Все процессы остановлены."
