#!/bin/bash
# VM1: API Gateway — iii Engine + Nginx
# This runs as user-data on first boot
set -euo pipefail
exec > /var/log/user-data.log 2>&1
echo "=== VM1 (API Gateway) setup started at $(date) ==="

# ── Install Docker ──
apt-get update
apt-get install -y curl git
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

# ── Clone repo ──
git clone ${github_repo} /opt/app
chown -R ubuntu:ubuntu /opt/app

# ── Start services ──
cd /opt/app
DOCKERHUB_USER=${dockerhub_user} docker compose -f docker-compose.vm1.yml up -d

echo "=== VM1 setup complete at $(date) ==="
