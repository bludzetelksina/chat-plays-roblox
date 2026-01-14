FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Базовые зависимости + ca-certificates для HTTPS
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
        software-properties-common \
        apt-transport-https \
        xvfb \
        pulseaudio \
        ffmpeg \
        locales && \
    rm -rf /var/lib/apt/lists/*

# Включаем i386
RUN dpkg --add-architecture i386

# Добавляем ключ и репозиторий OBS для libfaudio0
RUN wget -O- https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_22.04/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/libfaudio-obs.gpg > /dev/null
RUN echo "deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_22.04 ./ " > /etc/apt/sources.list.d/libfaudio.list

# Добавляем репозиторий WineHQ
RUN wget -O /etc/apt/trusted.gpg.d/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
RUN echo "deb https://dl.winehq.org/wine-builds/ubuntu/ jammy main" > /etc/apt/sources.list.d/winehq.list

# Обновляем и устанавливаем всё вместе
RUN apt-get update && \
    apt-get install -y --install-recommends \
        libfaudio0:i386 \
        winehq-stable && \
    rm -rf /var/lib/apt/lists/*

# winetricks
RUN mkdir -p /opt && \
    cd /opt && \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x winetricks

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

ENTRYPOINT ["/app/scripts/run_all.sh"]
