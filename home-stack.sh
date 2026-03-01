#!/bin/bash

# --- CONFIGURATION ---
# Replace /mnt/ironwolf with your actual IronWolf mount path
IRONWOLF="/mnt/ironwolf"
NVME_HOME="$HOME/server-stack"

echo "🚀 Starting Home-Stack Setup..."

# 1. Update and Install Prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl intel-gpu-tools mesa-va-drivers intel-media-va-driver-non-free

# 2. Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
else
    echo "Docker already installed."
fi

# 3. Create Folder Structure
echo "Creating folders on NVMe (Fast) and IronWolf (Bulk)..."
# Fast Storage (NVMe)
mkdir -p $NVME_HOME/{immich-db,jellyfin-config,steam-config,beszel-data}
# Bulk Storage (IronWolf)
sudo mkdir -p $IRONWOLF/{photos,movies,steam-library}
sudo chown -R $USER:$USER $IRONWOLF
sudo chown -R $USER:$USER $NVME_HOME

# 4. Generate .env file for Immich
cat <<EOF > $NVME_HOME/.env
# Database Credentials
DB_PASSWORD=$(openssl rand -hex 16)
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
# Storage
UPLOAD_LOCATION=$IRONWOLF/photos
# Version
IMMICH_VERSION=release
# Intel GPU Acceleration
IMMICH_PROFILES_HWACCEL=vaapi
EOF

# 5. Generate Unified docker-compose.yml
cat <<EOF > $NVME_HOME/docker-compose.yml
services:
  # GAMING: Steam-Headless (Virtual Desktop)
  steam:
    image: joshuaboniface/steam-headless:latest
    container_name: steam-headless
    privileged: true
    ports:
      - "8081:8080" # Management UI
      - "5900:5900" # VNC
    devices:
      - /dev/dri:/dev/dri
    environment:
      - USER_PASSWORD=your_secure_password
      - ENABLE_GPU=true
      - DISPLAY_WIDTH=1920
      - DISPLAY_HEIGHT=1080
    ulimits:
      nofile:
        soft: 1024
        hard: 524288
    volumes:
      - $NVME_HOME/steam-config:/home/steam/.local/share/Steam
      - $IRONWOLF/steam-library:/home/steam/SteamLibrary
    restart: unless-stopped

  # PHOTOS: Immich
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich_server
    devices: ["/dev/dri:/dev/dri"]
    volumes:
      - $IRONWOLF/photos:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    env_file: [.env]
    ports: ["2283:3001"]
    depends_on: [database, redis]
    restart: unless-stopped

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    container_name: immich_ml
    devices: ["/dev/dri:/dev/dri"]
    env_file: [.env]
    restart: unless-stopped

  database:
    image: ghcr.io/immich-app/postgres:16-vectorchord
    environment:
      POSTGRES_PASSWORD: \${DB_PASSWORD}
      POSTGRES_USER: \${DB_USERNAME}
      POSTGRES_DB: \${DB_DATABASE_NAME}
    volumes:
      - $NVME_HOME/immich-db:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: registry.hub.docker.com/library/redis:6.2-alpine
    restart: unless-stopped

  # MEDIA: Jellyfin
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    network_mode: host
    devices: ["/dev/dri:/dev/dri"]
    volumes:
      - $NVME_HOME/jellyfin-config:/config
      - $IRONWOLF/movies:/data
    restart: unless-stopped

  # MONITORING: Beszel
  beszel-hub:
    image: henrygd/beszel:latest
    container_name: beszel-hub
    ports: ["8090:8090"]
    volumes: ["$NVME_HOME/beszel-data:/beszel_data"]
    restart: unless-stopped

  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    devices: ["/dev/dri:/dev/dri"]
    environment:
      - PORT=4567
      - KEY="PLACEHOLDER" # Update this from Beszel UI later
    restart: unless-stopped
EOF

echo "✅ Script complete!"
echo "1. Log out and back in (to activate Docker permissions)."
echo "2. Run: cd $NVME_HOME && docker compose up -d"
echo "3. Access your apps:"
echo " - Steam: http://your-ip:8081"
echo " - Immich: http://your-ip:2283"
echo " - Jellyfin: http://your-ip:8096"
echo " - Beszel: http://your-ip:8090"

