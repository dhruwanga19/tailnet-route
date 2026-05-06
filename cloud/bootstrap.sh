#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu 22.04 ARM Lightsail instance for tailnet-route.
# Run as the default 'ubuntu' user. Idempotent.
set -euo pipefail

REPO_URL="${REPO_URL:-}"   # e.g. git@github.com:youruser/tailnet-route.git — optional
APP_DIR="${APP_DIR:-/opt/tsroute}"

echo "==> updating apt"
sudo apt-get update -y
sudo apt-get upgrade -y

echo "==> installing prerequisites"
sudo apt-get install -y ca-certificates curl gnupg ufw unattended-upgrades

echo "==> installing docker engine + compose plugin"
if ! command -v docker >/dev/null 2>&1; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  ARCH=$(dpkg --print-architecture)
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker ubuntu
fi

echo "==> enabling ip forwarding (kernel-mode tailscale exit node)"
sudo tee /etc/sysctl.d/99-tsroute.conf >/dev/null <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sudo sysctl --system >/dev/null

echo "==> ufw: allow ssh + tailscale UDP 41641 (Lightsail's own firewall is the primary gate)"
sudo ufw allow 22/tcp
sudo ufw allow 41641/udp
sudo ufw --force enable

echo "==> unattended-upgrades on"
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> preparing app dir at $APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo chown ubuntu:ubuntu "$APP_DIR"

if [[ -n "$REPO_URL" && ! -d "$APP_DIR/.git" ]]; then
  echo "==> cloning repo"
  git clone "$REPO_URL" "$APP_DIR"
fi

cat <<EOF

==============================================================
 Bootstrap complete. Next:

   1. cd $APP_DIR
   2. cp .env.example .env  (skip if you already rsync'd it)
   3. Set TS_AUTHKEY (fresh key, tag:exit) and TS_HOSTNAME=tsroute-prod
   4. Set TS_USERSPACE=false
   5. docker compose -f docker-compose.yml -f docker-compose.cloud.yml up -d

 If you just added the ubuntu user to the docker group, log out and back in
 (or: 'newgrp docker') so 'docker' works without sudo.
==============================================================
EOF
