#!/usr/bin/env bash

# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apk add curl
$STD apk add openjdk17-jre
msg_ok "Installed Dependencies"

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}
BEDROCK_CONNECT_LATEST_VERSION=$(get_latest_release "Pugmatt/BedrockConnect")

msg_info "Installing Bedrock Connect $BEDROCK_CONNECT_LATEST_VERSION"
mkdir -p /opt/bedrock-connect
curl -sSL https://github.com/Pugmatt/BedrockConnect/releases/download/$BEDROCK_CONNECT_LATEST_VERSION/BedrockConnect-1.0-SNAPSHOT.jar -o /opt/bedrock-connect/bedrock_connect.jar

mkdir -p /etc/init.d

cat >/opt/bedrock-connect/servers.json <<EOF
[
]
EOF

cat >/etc/init.d/bedrock_connect <<EOF
#!/sbin/openrc-run
description="Bedrock Connect"
command=/usr/bin/java
command_args=-jar /opt/bedrock-connect/bedrock_connect.jar nodb=true custom_servers=/opt/bedrock-connect/servers.json featured_servers=false
command_background=true
directory=/opt/tomcat
pidfile="/run/\${RC_SVCNAME}.pid"
EOF
rc-service bedrock_connect start
rc-update add bedrock_connect default
msg_ok "Installed Bedrock Connect $BEDROCK_CONNECT_LATEST_VERSION"

motd_ssh
customize

SERVER_ADDR="$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d "/" -f 1)"

msg_ok "Installed Bedrock Connect"
msg_ok "Connect to $SERVER_ADDR"