#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$ROOT_DIR/logs"
PID_FILE="$LOGS_DIR/roblox.pid"

# Функция: завершить процесс и его детей
kill_tree() {
    local pid=$1
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        return
    fi

    # Получаем всех потомков через pgrep
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    
    # Рекурсивно убиваем детей
    for child in $children; do
        kill_tree "$child"
    done

    # Завершаем основной процесс
    echo "⏹ Завершение процесса $pid..."
    kill "$pid" 2>/dev/null || true
    sleep 2

    # Если жив — принудительно
    if kill -0 "$pid" 2>/dev/null; then
        echo "⚠️ Принудительное завершение $pid"
        kill -9 "$pid" 2>/dev/null || true
    fi
}

echo "🛑 Остановка Roblox..."

# Способ 1: через PID-файл (создан launch_roblox.sh)
if [ -f "$PID_FILE" ]; then
    ROBLOX_PID=$(cat "$PID_FILE")
    if [ -n "$ROBLOX_PID" ] && [ "$ROBLOX_PID" -gt 0 ] 2>/dev/null; then
        kill_tree "$ROBLOX_PID"
        rm -f "$PID_FILE"
        echo "✅ Roblox остановлен по PID."
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

# Способ 2: fallback — поиск по имени процесса Wine
echo "🔍 Поиск процессов Roblox через Wine..."
WINE_PROCESSES=$(pgrep -f "wine.*Roblox" 2>/dev/null || true)

if [ -n "$WINE_PROCESSES" ]; then
    for pid in $WINE_PROCESSES; do
        kill_tree "$pid"
    done
    echo "✅ Все процессы Roblox завершены."
else
    echo "ℹ️ Roblox не запущен (PID-файл отсутствует, процессы не найдены)."
fi
