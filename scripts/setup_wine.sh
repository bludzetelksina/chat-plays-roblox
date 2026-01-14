#!/bin/bash
WINEPREFIX="$PWD/config/wine_prefix"
mkdir -p "$WINEPREFIX"

# Установка базовых зависимостей (например, corefonts)
winetricks -q corefonts vcrun2019
