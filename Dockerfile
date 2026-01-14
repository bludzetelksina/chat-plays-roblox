FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Шаг 1: Включаем universe/multiverse и добавляем i386
RUN dpkg --add-architecture i386 && \
    sed -i 's/^deb http:\/\/archive.ubuntu.com\/ubuntu jammy main$/deb http:\/\/archive.ubuntu.com\/ubuntu jammy main universe multiverse/' /etc/apt/sources.list && \
    sed -i 's/^deb http:\/\/archive.ubuntu.com\/ubuntu jammy-updates main$/deb http:\/\/archive.ubuntu.com\/ubuntu jammy-updates main universe multiverse/' /etc/apt/sources.list && \
    sed -i 's/^deb http:\/\/security.ubuntu.com\/ubuntu jammy-security main$/deb http:\/\/security.ubuntu.com\/ubuntu jammy-security main universe multiverse/' /etc/apt/sources.list

# Шаг 2: Устанавливаем зависимости
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
        xvfb \
        pulseaudio \
        ffmpeg \
        locales && \
    rm -rf /var/lib/apt/lists/*

# Шаг 3: Устанавливаем wine (i386) и winetricks из официальных репозиториев
RUN apt-get update && \
    apt-get install -y --install-recommends \
        wine \
        wine32 \
        winetricks && \
    rm -rf /var/lib/apt/lists/*

# Локаль
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app
COPY scripts/ ./scripts/
COPY config/ ./config/
RUN chmod +x scripts/*.sh

RUN useradd --create-home --shell /bin/bash roblox
USER roblox
ENV HOME=/home/roblox
ENV WINEPREFIX=/app/config/wine_prefix

ENTRYPOINT ["/app/scripts/run_all.sh"]]
