#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/octaviodimarco/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Antigravity AI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://opentelemetry.io/ | Github: https://github.com/open-telemetry/opentelemetry-collector

APP="OTel-Collector"
var_tags="${var_tags:-monitoring;otel}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-256}"
var_disk="${var_disk:-2}"
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
  if [[ ! -d /opt/otelcol ]]; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi

  if check_for_gh_release "otelcol" "open-telemetry/opentelemetry-collector-releases"; then
    msg_info "Updating OTel Collector in CT ${CTID}"
    pct exec "$CTID" -- bash -c '
      systemctl stop otelcol
      RELEASE_URL=$(curl -sL https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest | grep "browser_download_url.*otelcol_.*_linux_amd64.tar.gz" | grep -v "contrib\|otlp\|k8s" | head -1 | cut -d"\"" -f4)
      if [[ -n "$RELEASE_URL" ]]; then
        cd /tmp && rm -rf otelcol_upd && mkdir otelcol_upd && cd otelcol_upd
        curl -fsSL "$RELEASE_URL" -o otelcol.tar.gz && tar -xzf otelcol.tar.gz
        mkdir -p /opt/otelcol/bin
        find . -name otelcol -type f -executable | head -1 | xargs -I{} cp -f {} /opt/otelcol/bin/
        cd /tmp && rm -rf otelcol_upd
      fi
      systemctl start otelcol
    '
    msg_ok "Updated successfully!"
  fi
  exit 0
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Listening on:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}gRPC: ${IP}:4317${CL}"
echo -e "${TAB}${GATEWAY}${BGN}HTTP: ${IP}:4318${CL}"
