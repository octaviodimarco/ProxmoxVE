#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Antigravity AI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://opentelemetry.io/ | Github: https://github.com/open-telemetry/opentelemetry-collector

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  curl \
  ca-certificates
msg_ok "Installed Dependencies"

msg_info "Setting up OpenTelemetry Collector (Core)"
fetch_and_deploy_gh_release "otelcol" "open-telemetry/opentelemetry-collector-releases" "prebuild" "latest" "/opt/otelcol" "otelcol_*_linux_amd64.tar.gz"

msg_info "Configuring OpenTelemetry Collector"
mkdir -p /etc/otelcol
# Variable de entorno con fallback (sin read interactivo para instalación automatizada)
LOKI_URL="${LOKI_URL:-http://localhost:3100/otlp}"

cat <<EOF >/etc/otelcol/config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  debug:
    verbosity: basic
  otlphttp/loki:
    endpoint: "${LOKI_URL}"
    tls:
      insecure: true

service:
  pipelines:
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug, otlphttp/loki]
EOF

cat <<EOF >/etc/systemd/system/otelcol.service
[Unit]
Description=OpenTelemetry Collector (Core)
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/otelcol/bin/otelcol --config=/etc/otelcol/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now otelcol
msg_ok "Setup OpenTelemetry Collector"

motd_ssh
customize
cleanup_lxc
