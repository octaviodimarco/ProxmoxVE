#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://plant-it.org/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
    curl \
    mc \
    sudo \
    gnupg2 \
    nginx
msg_ok "Installed Dependencies"

msg_info "Setting up Adoptium Repository"
mkdir -p /etc/apt/keyrings
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor >/etc/apt/trusted.gpg.d/adoptium.gpg
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" >/etc/apt/sources.list.d/adoptium.list
$STD apt-get update
msg_ok "Set up Adoptium Repository"

msg_info "Installing Temurin JDK 21 (LTS)"
$STD apt-get install -y temurin-21-jdk
msg_ok "Setup Temurin JDK 21 (LTS)"

# Solicitar credenciales de la base de datos MySQL externa
msg_info "Configuring External MySQL Database"
read -p "Enter the external MySQL host (e.g., db.example.com): " MYSQL_HOST
read -p "Enter the external MySQL port (e.g., 3306): " MYSQL_PORT
read -p "Enter the external MySQL database name: " MYSQL_DATABASE
read -p "Enter the external MySQL username: " MYSQL_USERNAME
read -s -p "Enter the external MySQL password: " MYSQL_PASSWORD
echo ""  # Salto de línea después de la contraseña

msg_ok "External MySQL Database Configuration Complete"

# Solicitar credenciales de Redis externo
msg_info "Configuring External Redis"
read -p "Enter the external Redis host (e.g., redis.example.com): " REDIS_HOST
read -p "Enter the external Redis port (e.g., 6379): " REDIS_PORT
read -s -p "Enter the external Redis password (leave empty if none): " REDIS_PASSWORD
echo ""  # Salto de línea después de la contraseña

msg_ok "External Redis Configuration Complete"

msg_info "Setup Plant-it"
RELEASE=$(curl -s https://api.github.com/repos/MDeLuise/plant-it/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q https://github.com/MDeLuise/plant-it/releases/download/${RELEASE}/server.jar
mkdir -p /opt/plant-it/{backend,frontend}
mkdir -p /opt/plant-it-data
mv -f server.jar /opt/plant-it/backend/server.jar

# Generar JWT_SECRET
JWT_SECRET=$(openssl rand -base64 24 | tr -d '/+=')

# Crear archivo de configuración del servidor para MySQL y Redis externos
cat <<EOF >/opt/plant-it/backend/server.env
MYSQL_HOST=$MYSQL_HOST
MYSQL_PORT=$MYSQL_PORT
MYSQL_USERNAME=$MYSQL_USERNAME
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE

JWT_SECRET=$JWT_SECRET
JWT_EXP=1

USERS_LIMIT=-1
UPLOAD_DIR=/opt/plant-it-data
API_PORT=8080
FLORACODEX_KEY=
LOG_LEVEL=DEBUG
ALLOWED_ORIGINS=*

CACHE_TYPE=redis
CACHE_TTL=86400
CACHE_HOST=$REDIS_HOST
CACHE_PORT=$REDIS_PORT
CACHE_PASSWORD=$REDIS_PASSWORD
EOF

cd /opt/plant-it/frontend
wget -q https://github.com/MDeLuise/plant-it/releases/download/${RELEASE}/client.tar.gz
tar -xzf client.tar.gz
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Setup Plant-it"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/plant-it.service
[Unit]
Description=Plant-it Backend Service
After=syslog.target network.target

[Service]
Type=simple
WorkingDirectory=/opt/plant-it/backend
EnvironmentFile=/opt/plant-it/backend/server.env
ExecStart=/usr/bin/java -jar -Xmx2g server.jar
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now -q plant-it

cat <<EOF >/etc/nginx/nginx.conf
events {
    worker_connections 1024;
}

http {
    server {
        listen 3000;
        server_name localhost;

        root /opt/plant-it/frontend;
        index index.html;

        location / {
            try_files \$uri \$uri/ /index.html;
        }

        error_page 404 /404.html;
        location = /404.html {
            internal;
        }
    }
}
EOF
systemctl restart nginx
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /opt/plant-it/frontend/client.tar.gz
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"