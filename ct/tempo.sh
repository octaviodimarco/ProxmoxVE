#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/octaviodimarco/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Antigravity AI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://grafana.com/oss/tempo/ | Github: https://github.com/grafana/tempo

APP="Tempo"
var_tags="${var_tags:-monitoring;traces;grafana}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if ! dpkg -s tempo >/dev/null 2>&1; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi

  msg_info "Updating Tempo"
  systemctl stop tempo
  $STD apt update
  $STD apt install -y --only-upgrade tempo
  systemctl start tempo
  msg_ok "Updated successfully!"
  exit 0
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Listening on:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}API:     ${IP}:3200${CL}"
echo -e "${TAB}${GATEWAY}${BGN}OTLP gRPC: ${IP}:4317${CL}"
echo -e "${TAB}${GATEWAY}${BGN}OTLP HTTP: ${IP}:4318${CL}"
echo -e "${INFO}${YW} Add Tempo data source in Grafana: http://${IP}:3200${CL}\n"
