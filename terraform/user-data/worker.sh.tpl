#!/bin/bash
# ${worker_name}: Deployed to private subnet
# Connects to iii engine on VM1 at ${engine_ip}:49134
set -euo pipefail
exec > /var/log/user-data.log 2>&1
echo "=== ${worker_name} setup started at $(date) ==="

# ── Install Docker ──
apt-get update
apt-get install -y curl git
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

# ── Clone repo ──
git clone ${github_repo} /opt/app
chown -R ubuntu:ubuntu /opt/app

# ── Start worker ──
cd /opt/app
ENGINE_IP=${engine_ip} DOCKERHUB_USER=${dockerhub_user} docker compose -f ${compose_file} up -d

echo "=== ${worker_name} setup complete at $(date) ==="
