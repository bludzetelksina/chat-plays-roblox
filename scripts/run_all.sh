#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$ROOT_DIR/logs"
CONFIG_DIR="$ROOT_DIR/config"
ASSETS_DIR="$ROOT_DIR/assets"

mkdir -p "$LOGS_DIR"

# === 1. Запуск виртуального X-сервера (DISPLAY=:0) ===
echo "🖥 Запуск Xvfb на :0..."
Xvfb :0 -screen 0 1280x720x24 -nolisten tcp -dpi 96 &
XVFB_PID=$!
export DISPLAY=:0

# Запуск минимального оконного менеджера (для фокуса окон)
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

# === 3. Запуск Roblox (фон, без TTY) ===
if [ -f "$ASSETS_DIR/RobloxPlayer.exe" ]; then
    echo "🎮 Запуск Roblox..."
    nohup env WINEPREFIX="$WINEPREFIX" wine "$ASSETS_DIR/RobloxPlayer.exe" \
        >/dev/null 2>"$LOGS_DIR/roblox_stderr.log" &
    ROBLOX_PID=$!
    echo $ROBLOX_PID > "$LOGS_DIR/roblox.pid"
else
    echo "⚠️ RobloxPlayer.exe не найден. Пропуск запуска игры."
fi

# === 4. Подготовка к управлению стримом ===
STREAM_PID_FILE="$LOGS_DIR/ffmpeg_stream.pid"

start_stream() {
    if [ -f "$STREAM_PID_FILE" ]; then
        echo "🔴 Стрим уже запущен."
        return
    fi
    echo "📡 Запуск FFmpeg-стрима..."
    ffmpeg -f x11grab -video_size 1280x720 -framerate 30 -i :0.0 \
           -f alsa -i pulse \
           -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
           -c:a aac -b:a 128k \
           -f flv "$(cat "$CONFIG_DIR/rtmp_url.txt")" \
           >/dev/null 2>"$LOGS_DIR/ffmpeg.log" &
    STREAM_PID=$!
    echo $STREAM_PID > "$STREAM_PID_FILE"
    echo "✅ Стрим запущен (PID: $STREAM_PID)"
}

stop_stream() {
    if [ -f "$STREAM_PID_FILE" ]; then
        STREAM_PID=$(cat "$STREAM_PID_FILE")
        if kill -0 "$STREAM_PID" 2>/dev/null; then
            kill "$STREAM_PID"
            sleep 2
            kill -9 "$STREAM_PID" 2>/dev/null || true
        fi
        rm -f "$STREAM_PID_FILE"
        echo "⏹ Стрим остановлен."
    else
        echo "ℹ️ Стрим не запущен."
    fi
}

# Экспортируем функции для вызова из Python (через subprocess)
export -f start_stream
export -f stop_stream
export SCRIPT_DIR LOGS_DIR CONFIG_DIR

# === 5. Запуск основного чат-бота ===
echo "🤖 Запуск Chat Uses: Roblox Edition..."
python3 "$ROOT_DIR/src/main.py"

# === 6. Очистка при завершении ===
echo "🧹 Завершение всех процессов..."
kill $XVFB_PID $FLUXBOX_PID 2>/dev/null || true

if [ -f "$LOGS_DIR/roblox.pid" ]; then
    ROBLOX_PID=$(cat "$LOGS_DIR/roblox.pid")
    kill $ROBLOX_PID 2>/dev/null || true
    rm -f "$LOGS_DIR/roblox.pid"
fi

stop_stream
