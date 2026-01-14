#!/bin/bash
cd "$(dirname "$0")/.."

# Загрузка конфигурации
source config/ffmpeg_stream.conf

# Пример команды FFmpeg
ffmpeg -f x11grab -video_size 1280x720 -framerate 30 -i :0.0 \
       -f alsa -i pulse \
       -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
       -c:a aac -b:a 128k \
       -f flv "$RTMP_URL"
