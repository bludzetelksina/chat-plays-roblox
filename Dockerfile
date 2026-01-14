FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Включаем multiverse и universe
RUN sed -i 's/^#\s*deb/deb/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
        xvfb \
        pulseaudio \
        ffmpeg \
        locales \
        software-properties-common && \
    rm -rf /var/lib/apt/lists/*

# Включаем i386
RUN dpkg --add-architecture i386

# Обновляем и ставим Wine из официального репозитория Ubuntu
RUN apt-get update && \
    apt-get install -y --install-recommends \
        wine:i386 \
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

ENTRYPOINT ["/app/scripts/run_all.sh"]
