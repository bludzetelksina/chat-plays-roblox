#!/bin/bash
export DISPLAY=:0
cd "$(dirname "$0")/.."
WINEPREFIX="$PWD/config/wine_prefix" wine "$PWD/assets/RobloxPlayer.exe" "$@"
