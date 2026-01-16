#!/bin/bash
set -e

# === Настройки ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

cd "$ROOT_DIR/src"

# === 1. Установка Python-зависимостей (если нужно) ===
echo "📦 Установка Python-зависимостей..."
pip3 install --user --no-cache-dir \
    google-api-python-client \
    google-auth-oauthlib \
    pyautogui \
    pygame \
    gTTS \
    requests

# === 2. Запуск стрима в фоне ===
echo "📡 Запуск FFmpeg-стрима..."
"$SCRIPT_DIR/stream_control.sh" start &

STREAM_PID=$!

# Даем время на инициализацию
sleep 3

bash scripts/run-all.sh

# === 3. Запуск основного чат-бота ===
echo "🤖 Запуск Chat Uses: Roblox Edition..."
python3 main.py

# === 4. Очистка при завершении ===
echo "⏹ Остановка стрима..."
kill $STREAM_PID 2>/dev/null || true
wait $STREAM_PID 2>/dev/null || true
"$SCRIPT_DIR/stream_control.sh" stop
