#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Antigravity AI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://grafana.com/oss/tempo/ | Github: https://github.com/grafana/tempo

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

setup_deb822_repo \
  "grafana" \
  "https://apt.grafana.com/gpg.key" \
  "https://apt.grafana.com" \
  "stable" \
  "main"

msg_info "Installing Tempo"
$STD apt install -y tempo
msg_ok "Installed Tempo"

msg_info "Configuring Tempo"
mkdir -p /etc/tempo /var/tempo/{blocks,wal}
chown -R tempo /var/tempo 2>/dev/null || chown -R root /var/tempo

cat <<EOF >/etc/tempo/config.yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

ingester:
  max_block_duration: 5m

compactor:
  compaction:
    block_retention: 48h

storage:
  trace:
    backend: local
    local:
      path: /var/tempo/blocks
    wal:
      path: /var/tempo/wal
EOF

systemctl enable -q --now tempo
msg_ok "Setup Tempo"

motd_ssh
customize
cleanup_lxc
