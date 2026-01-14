# Используем Ubuntu 22.04 как базу (стабильная поддержка Wine + FFmpeg)
FROM ubuntu:22.04

# Предотвращаем интерактивные запросы при установке
ENV DEBIAN_FRONTEND=noninteractive

# Установка системных зависимостей
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        gnupg \
        software-properties-common \
        x11vnc \
        xvfb \
        fluxbox \
        alsa-utils \
        pulseaudio \
        ffmpeg \
        git \
        ca-certificates \
        locales \
        dbus-x11 && \
    rm -rf /var/lib/apt/lists/*

RUN dpkg --add-architecture i386 && \
    wget -O /etc/apt/trusted.gpg.d/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    echo "deb https://dl.winehq.org/wine-builds/ubuntu/ jammy main" > /etc/apt/sources.list.d/winehq.list && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    rm -rf /var/lib/apt/lists/*

# Установка winetricks
RUN mkdir -p /opt && \
    cd /opt && \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x winetricks

# Настройка локали (важно для Wine)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Создание рабочей директории
WORKDIR /app

# Копирование скриптов и конфигов
COPY scripts/ ./scripts/
COPY config/ ./config/

# Делаем скрипты исполняемыми
RUN chmod +x scripts/*.sh

# Создаём пользователя без root-прав (безопасность)
RUN useradd --create-home --shell /bin/bash roblox
USER roblox
ENV HOME=/home/roblox
ENV WINEPREFIX=/app/config/wine_prefix

# Запуск всего через точку входа
ENTRYPOINT ["/app/scripts/run_all.sh"]
