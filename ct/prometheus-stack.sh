#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/octaviodimarco/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: tteck (tteckster) | Marfnl | Andy Grunwald (andygrunwald)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://prometheus.io/ | Github: https://github.com/prometheus/prometheus

APP="Prometheus-Stack"
var_tags="${var_tags:-monitoring;alerting}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /etc/systemd/system/prometheus.service ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "prometheus" "prometheus/prometheus"; then
    msg_info "Stopping Prometheus"
    systemctl stop prometheus
    msg_ok "Stopped Prometheus"

    fetch_and_deploy_gh_release "prometheus" "prometheus/prometheus" "prebuild" "latest" "/usr/local/bin" "*linux-amd64.tar.gz"
    rm -f /usr/local/bin/prometheus.yml

    msg_info "Starting Prometheus"
    systemctl start prometheus
    msg_ok "Started Prometheus"
    msg_ok "Updated Prometheus successfully!"
  fi

  if check_for_gh_release "alertmanager" "prometheus/alertmanager"; then
    msg_info "Stopping Alertmanager"
    systemctl stop prometheus-alertmanager
    msg_ok "Stopped Alertmanager"

    fetch_and_deploy_gh_release "alertmanager" "prometheus/alertmanager" "prebuild" "latest" "/usr/local/bin/" "alertmanager*linux-amd64.tar.gz"

    msg_info "Starting Alertmanager"
    systemctl start prometheus-alertmanager
    msg_ok "Started Alertmanager"
    msg_ok "Updated Alertmanager successfully!"
  fi

  if check_for_gh_release "blackbox-exporter" "prometheus/blackbox_exporter"; then
    msg_info "Stopping Blackbox Exporter"
    systemctl stop blackbox-exporter
    msg_ok "Stopped Blackbox Exporter"

    msg_info "Creating backup"
    mv /opt/blackbox-exporter/blackbox.yml /opt
    msg_ok "Backup created"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "blackbox-exporter" "prometheus/blackbox_exporter" "prebuild" "latest" "/opt/blackbox-exporter" "blackbox_exporter-*.linux-amd64.tar.gz"

    msg_info "Restoring backup"
    cp -r /opt/blackbox.yml /opt/blackbox-exporter
    rm -f /opt/blackbox.yml
    msg_ok "Backup restored"

    msg_info "Starting Blackbox Exporter"
    systemctl start blackbox-exporter
    msg_ok "Started Blackbox Exporter"
    msg_ok "Updated Blackbox Exporter successfully!"
  fi

  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URLs:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9090${CL} ${GN}(Prometheus)${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9093${CL} ${GN}(Alertmanager)${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9115${CL} ${GN}(Blackbox Exporter)${CL}"
