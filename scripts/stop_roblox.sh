#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/../logs/roblox.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "⏹ Остановка Roblox (PID: $PID)..."
        kill "$PID"
        sleep 3
        kill -9 "$PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
else
    echo "⚠️ Roblox не запущен (PID-файл не найден)."
fi
