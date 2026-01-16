FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    DISPLAY=:0

# Установка системных пакетов (как раньше)
RUN dpkg --add-architecture i386 && \
    sed -i 's/^deb http:\/\/archive\.ubuntu\.com\/ubuntu jammy main$/& universe multiverse/' /etc/apt/sources.list && \
    sed -i 's/^deb http:\/\/archive\.ubuntu\.com\/ubuntu jammy-updates main$/& universe multiverse/' /etc/apt/sources.list && \
    sed -i 's/^deb http:\/\/security\.ubuntu\.com\/ubuntu jammy-security main$/& universe multiverse/' /etc/apt/sources.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates wget gnupg software-properties-common \
        xvfb fluxbox x11vnc pulseaudio alsa-utils ffmpeg \
        python3 python3-pip python3-pyaudio locales git dbus-x11 && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y --install-recommends wine wine32 winetricks && \
    rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 ru_RU.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

RUN pip3 install pyautogui pygame gTTS requests

# === КРИТИЧЕСКИ ВАЖНО: права ===
RUN useradd --create-home --shell /bin/bash roblox

# Копируем от root
COPY . /app/

# Даём владельца и исполняемые права
RUN chown -R roblox:roblox /app && \
    chmod +x /app/scripts/*.sh

USER roblox
ENV HOME=/home/roblox \
    WINEPREFIX=/app/config/wine_prefix

WORKDIR /app

ENTRYPOINT ["/app/scripts/run_all.sh"]
