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

# Даем время на инициализацию
sleep 3

# === 3. Запуск основного чат-бота ===
echo "🤖 Запуск Chat Uses: Roblox Edition..."
python3 main.py
