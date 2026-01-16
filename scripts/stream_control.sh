#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$ROOT_DIR/logs"
CONFIG_DIR="$ROOT_DIR/config"

# === Гарантируем создание логов ===
mkdir -p "$LOGS_DIR"
FFMPEG_LOG="$LOGS_DIR/ffmpeg.log"
FFMPEG_STREAM_LOG="$LOGS_DIR/ffmpeg_stream.log"

touch "$FFMPEG_LOG" "$FFMPEG_STREAM_LOG"
chmod 644 "$FFMPEG_LOG" "$FFMPEG_STREAM_LOG"
echo "📝 FFmpeg логи готовы: $FFMPEG_LOG, $FFMPEG_STREAM_LOG"

# === Вспомогательные функции ===

get_rtmp_url() {
    RTMP_FILE="$CONFIG_DIR/rtmp_url.txt"
    if [ ! -f "$RTMP_FILE" ]; then
        echo "❌ RTMP-файл не найден: $RTMP_FILE" >&2
        exit 1
    fi
    RTMP_URL=$(head -n1 "$RTMP_FILE" | tr -d '\r\n ')
    if [ -z "$RTMP_URL" ] || [[ ! "$RTMP_URL" =~ ^rtmp:// ]]; then
        echo "❌ Некорректный RTMP URL" >&2
        exit 1
    fi
    echo "$RTMP_URL"
}

# Ищет FFmpeg-процесс по уникальному аргументу
is_stream_running() {
    pgrep -f "ffmpeg.*x11grab.*:0.0.*flv.*rtmp" > /dev/null 2>&1
}

get_stream_pid() {
    pgrep -f "ffmpeg.*x11grab.*:0.0.*flv.*rtmp" 2>/dev/null | head -n1
}

# === Команды ===

start_stream() {
    if is_stream_running; then
        echo "ℹ️ Стрим уже запущен."
        return 0
    fi

    RTMP_URL=$(get_rtmp_url)
    echo "📡 Запуск FFmpeg-трансляции..."

    # Запуск в фоне с логированием
    ffmpeg -f x11grab -video_size 1280x720 -framerate 30 -i :0.0 -f alsa -i pulse \
        -c:v libx264 -preset ultrafast -pix_fmt yuv420p -b:v 4500k \
        -c:a aac -b:a 128k -ar 44100 \
        -f flv "$RTMP_URL"
    
    sleep 1
    if is_stream_running; then
        echo "✅ Стрим запущен."
    else
        echo "❌ Не удалось запустить FFmpeg. См. логи."
        exit 1
    fi
}

stop_stream() {
    if ! is_stream_running; then
        echo "ℹ️ Стрим не запущен."
        return 0
    fi

    echo "⏹ Остановка стрима..."
    kill -f "ffmpeg.*x11grab.*:0.0.*flv.*rtmp"
    sleep 3

    echo "✅ Стрим остановлен."
}

status_stream() {
    if is_stream_running; then
        echo "🟢 Стрим активен."
        exit 0
    else
        echo "🔴 Стрим не запущен."
        exit 1
    fi
}

restart_stream() {
    stop_stream
    sleep 2
    start_stream
}

# === Основной парсер ===
case "${1:-}" in
    start)
        start_stream
        ;;
    stop)
        stop_stream
        ;;
    restart)
        restart_stream
        ;;
    status)
        status_stream
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
