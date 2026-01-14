# Используем Ubuntu 22.04
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Установка базовых утилит и сертификатов
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
        software-properties-common \
        apt-transport-https \
        x11vnc \
        xvfb \
        fluxbox \
        pulseaudio \
        ffmpeg \
        locales && \
    rm -rf /var/lib/apt/lists/*

# Добавляем архитектуру i386
RUN dpkg --add-architecture i386

# Добавляем ключ WineHQ
RUN wget -O /etc/apt/trusted.gpg.d/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key

# Добавляем репозиторий WineHQ
RUN echo "deb https://dl.winehq.org/wine-builds/ubuntu/ jammy main" > /etc/apt/sources.list.d/winehq.list

# ⚠️ КРИТИЧЕСКИ ВАЖНО: добавляем репозиторий для libfaudio0 (требуется Wine)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libfaudio0:i386 && \
    rm -rf /var/lib/apt/lists/*

# Теперь можно установить Wine
RUN apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    rm -rf /var/lib/apt/lists/*

# Установка winetricks
RUN mkdir -p /opt && \
    cd /opt && \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x winetricks

# Локаль
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Рабочая директория
WORKDIR /app
COPY scripts/ ./scripts/
COPY config/ ./config/
RUN chmod +x scripts/*.sh

# Пользователь
RUN useradd --create-home --shell /bin/bash roblox
USER roblox
ENV HOME=/home/roblox
ENV WINEPREFIX=/app/config/wine_prefix

ENTRYPOINT ["/app/scripts/run_all.sh"]
