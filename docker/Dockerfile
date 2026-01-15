FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    DISPLAY=:0

# === 1. Включаем universe/multiverse и i386 ===
RUN dpkg --add-architecture i386 && \
    sed -i 's/^deb http:\/\/archive\.ubuntu\.com\/ubuntu jammy main$/& universe multiverse/' /etc/apt/sources.list && \
    sed -i 's/^deb http:\/\/archive\.ubuntu\.com\/ubuntu jammy-updates main$/& universe multiverse/' /etc/apt/sources.list && \
    sed -i 's/^deb http:\/\/security\.ubuntu\.com\/ubuntu jammy-security main$/& universe multiverse/' /etc/apt/sources.list

# === 2. Устанавливаем системные зависимости ===
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
        software-properties-common \
        xvfb \
        fluxbox \
        x11vnc \
        pulseaudio \
        alsa-utils \
        ffmpeg \
        python3 \
        python3-pip \
        python3-pyaudio \
        locales \
        git \
        dbus-x11 && \
    rm -rf /var/lib/apt/lists/*

# === 3. Устанавливаем Wine (из официального репозитория Ubuntu) ===
RUN apt-get update && \
    apt-get install -y --install-recommends \
        wine \
        wine32 \
        winetricks && \
    rm -rf /var/lib/apt/lists/*

# === 4. Настраиваем локаль ===
RUN locale-gen en_US.UTF-8 ru_RU.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# === 5. Устанавливаем Python-зависимости ===
RUN pip3 install pyautogui pygame gTTS requests

# === 6. Создаём рабочую директорию и пользователя ===
WORKDIR /app
RUN useradd --create-home --shell /bin/bash roblox
USER roblox
ENV HOME=/home/roblox \
    WINEPREFIX=/app/config/wine_prefix

# === 7. Копируем код ===
COPY --chown=roblox:roblox . /app/

# === 8. Делаем скрипты исполняемыми ===
RUN chmod +x scripts/run_all.sh

# === Точка входа ===
ENTRYPOINT ["/app/scripts/run_all.sh"]
