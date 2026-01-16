#!/bin/bash
set -e

# === Конфигурация ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$ROOT_DIR/logs"
CONFIG_DIR="$ROOT_DIR/config"

PID_FILE="$LOGS_DIR/ffmpeg_stream.pid"
LOG_FILE="$LOGS_DIR/ffmpeg.log"
RTMP_FILE="$CONFIG_DIR/rtmp_url.txt"

# Создаём директории
mkdir -p "$LOGS_DIR" "$CONFIG_DIR"

# === Функции ===
get_rtmp_url() {
    if [ ! -f "$RTMP_FILE" ]; then
        echo "❌ Ошибка: $RTMP_FILE не найден." >&2
        exit 1
    fi
    RTMP_URL=$(head -n1 "$RTMP_FILE" | tr -d '\r\n ')
    if [ -z "$RTMP_URL" ] || [[ "$RTMP_URL" != rtmp://* ]]; then
        echo "❌ Ошибка: некорректный RTMP URL в $RTMP_FILE." >&2
        exit 1
    fi
    echo "$RTMP_URL"
}

is_stream_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            return 0  # запущен
        else
            rm -f "$PID_FILE"  # мёртвый PID — удаляем
        fi
    fi
    return 1  # не запущен
}

start_stream() {
    if is_stream_running; then
        echo "ℹ️ Стрим уже запущен (PID: $(cat "$PID_file"))."
        exit 0
    fi

    RTMP_URL=$(get_rtmp_url)
    echo "📡 Запуск FFmpeg-трансляции на: ${RTMP_URL:0:30}..."

    # Запуск FFmpeg в фоне
    ffmpeg \
        -f x11grab -video_size 1280x720 -framerate 30 -i :0.0 \
        -f alsa -i pulse \
        -c:v libx264 -preset ultrafast -pix_fmt yuv420p -b:v 4500k \
        -c:a aac -b:a 128k -ar 44100 \
        -f flv "$RTMP_URL" \
        > "$LOG_FILE" 2>&1 &
    
    STREAM_PID=$!
    echo $STREAM_PID > "$PID_FILE"
    echo "✅ Стрим запущен. PID: $STREAM_PID"
}

stop_stream() {
    if ! is_stream_running; then
        echo "ℹ️ Стрим не запущен."
        exit 0
    fi

    PID=$(cat "$PID_FILE")
    echo "⏹ Остановка стрима (PID: $PID)..."

    # Мягкое завершение
    kill "$PID" 2>/dev/null || true
    sleep 3

    # Принудительное, если жив
    if kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID" 2>/dev/null || true
        echo "⚠️ Принудительное завершение FFmpeg."
    fi

    rm -f "$PID_FILE"
    echo "✅ Стрим остановлен."
}

# === Основной парсер аргументов ===
case "${1:-}" in
    start)
        start_stream
        ;;
    stop)
        stop_stream
        ;;
    status)
        if is_stream_running; then
            echo "🟢 Стрим активен (PID: $(cat "$PID_FILE"))"
            exit 0
        else
            echo "🔴 Стрим не запущен"
            exit 1
        fi
        ;;
    restart)
        stop_stream
        sleep 1
        start_stream
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
