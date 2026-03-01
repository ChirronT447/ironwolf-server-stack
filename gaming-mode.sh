#!/bin/bash

case "$1" in
    on)
        echo "🎮 Activating Gaming Mode..."
        echo "Pausing background hogs (Immich, Jellyfin)..."
        docker pause immich_server immich_ml jellyfin tvheadend
        echo "✅ GPU is now completely dedicated to Steam!"
        ;;
    off)
        echo "🛑 Deactivating Gaming Mode..."
        echo "Waking up background apps..."
        docker unpause immich_server immich_ml jellyfin tvheadend
        echo "✅ Media and photo backups are active again."
        ;;
    *)
        echo "Usage: ./gaming-mode.sh {on|off}"
        ;;
esac
