#!/bin/bash
set -e

# Запуск виртуального X-сервера
Xvfb :0 -screen 0 1280x720x24 -nolisten tcp &
export DISPLAY=:0

# Запуск PulseAudio (для аудио в FFmpeg, если нужно)
pulseaudio --daemonize --log-target=null

# Инициализация Wine (если префикс ещё не создан)
if [ ! -d "$WINEPREFIX" ]; then
    echo "Инициализация Wine prefix..."
    wineboot --init
    /opt/winetricks -q corefonts vcrun2019
fi

# Запуск Roblox в фоне
echo "Запуск Roblox..."
cd /app/assets
wine RobloxPlayer.exe &

# Запуск трансляции
echo "Запуск FFmpeg-трансляции..."
/app/scripts/start_stream.sh
