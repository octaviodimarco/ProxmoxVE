#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: tteck (tteckster) | Marfnl | Andy Grunwald (andygrunwald)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://prometheus.io/ | Github: https://github.com/prometheus/prometheus
#         https://github.com/prometheus/alertmanager
#         https://github.com/prometheus/blackbox_exporter

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# ---- Prometheus ----
fetch_and_deploy_gh_release "prometheus" "prometheus/prometheus" "prebuild" "latest" "/usr/local/bin" "*linux-amd64.tar.gz"

msg_info "Installing Prometheus"
mkdir -p /etc/prometheus /var/lib/prometheus
mv /usr/local/bin/prometheus.yml /etc/prometheus/prometheus.yml
msg_ok "Installed Prometheus"

msg_info "Creating Prometheus Service"
cat <<'EOF' >/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=root
Restart=always
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/ \
    --web.listen-address=0.0.0.0:9090
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now prometheus
msg_ok "Created Prometheus Service"

# ---- Alertmanager ----
fetch_and_deploy_gh_release "alertmanager" "prometheus/alertmanager" "prebuild" "latest" "/usr/local/bin/" "alertmanager*linux-amd64.tar.gz"

msg_info "Configuring Alertmanager"
mkdir -p /etc/alertmanager /var/lib/alertmanager
mv /usr/local/bin/alertmanager.yml /etc/alertmanager/alertmanager.yml
msg_ok "Configured Alertmanager"

msg_info "Creating Alertmanager Service"
cat <<EOF >/etc/systemd/system/prometheus-alertmanager.service
[Unit]
Description=Prometheus Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=root
Restart=always
Type=simple
ExecStart=/usr/local/bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/var/lib/alertmanager/ \
    --web.listen-address=0.0.0.0:9093
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now prometheus-alertmanager
msg_ok "Created Alertmanager Service"

# ---- Blackbox Exporter ----
fetch_and_deploy_gh_release "blackbox-exporter" "prometheus/blackbox_exporter" "prebuild" "latest" "/opt/blackbox-exporter" "blackbox_exporter-*.linux-amd64.tar.gz"

msg_info "Creating Blackbox Exporter Service"
cat <<EOF >/etc/systemd/system/blackbox-exporter.service
[Unit]
Description=Blackbox Exporter
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/blackbox-exporter
ExecStart=/opt/blackbox-exporter/blackbox_exporter \
    --web.listen-address=0.0.0.0:9115
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now blackbox-exporter
msg_ok "Created Blackbox Exporter Service"

motd_ssh
customize
cleanup_lxc
