#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$ROOT_DIR/logs"
WINEPREFIX="$ROOT_DIR/config/wine_prefix"
PID_FILE="$LOGS_DIR/roblox.pid"

# Функция: завершить дерево процессов
kill_tree() {
    local pid=$1
    [ -z "$pid" ] && return
    if ! kill -0 "$pid" 2>/dev/null; then
        return
    fi

    # Убиваем потомков рекурсивно
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
        kill_tree "$child"
    done

    kill "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
    fi
}

echo "🛑 Остановка всех процессов Wine в префиксе: $WINEPREFIX"

# 1. Через PID-файл (если есть)
if [ -f "$PID_FILE" ]; then
    ROBLOX_PID=$(cat "$PID_FILE")
    if [ -n "$ROBLOX_PID" ] && kill -0 "$ROBLOX_PID" 2>/dev/null; then
        kill_tree "$ROBLOX_PID"
    fi
    rm -f "$PID_FILE"
fi

# 2. Поиск ВСЕХ процессов, использующих этот WINEPREFIX
echo "🔍 Поиск процессов по WINEPREFIX..."
# Wine устанавливает переменную окружения WINEPREFIX для своих процессов
# Но pgrep не видит env → ищем через /proc/*/environ
FOUND_PIDS=""

for pid in /proc/[0-9]*; do
    pid_num=$(basename "$pid")
    if [ -f "$pid/environ" ]; then
        # Проверяем, содержит ли environ путь к нашему WINEPREFIX
        if tr '\0' '\n' < "$pid/environ" 2>/dev/null | grep -q "WINEPREFIX=$WINEPREFIX"; then
            FOUND_PIDS="$FOUND_PIDS $pid_num"
        fi
    fi
done

if [ -n "$FOUND_PIDS" ]; then
    echo "📦 Найдены процессы Wine: $FOUND_PIDS"
    for pid in $FOUND_PIDS; do
        kill_tree "$pid"
    done
else
    echo "ℹ️ Активные процессы Wine не найдены."
fi

# 3. Дополнительно: завершаем wine-server для этого префикса
echo "🔌 Остановка wine-server..."
WINEDEBUG=-all WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null || true
sleep 1
WINEDEBUG=-all WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null || true
pkill -f wine

echo "✅ Все процессы Wine для Roblox остановлены."
