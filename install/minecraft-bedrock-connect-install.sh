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
$STD apk add supervisor
msg_ok "Installed Dependencies"

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}
BEDROCK_CONNECT_LATEST_VERSION=$(get_latest_release "Pugmatt/BedrockConnect")

msg_info "Installing Bedrock Connect $BEDROCK_CONNECT_LATEST_VERSION"
mkdir -p /opt/bedrock-connect
curl -sSL https://github.com/Pugmatt/BedrockConnect/releases/download/$BEDROCK_CONNECT_LATEST_VERSION/BedrockConnect-1.0-SNAPSHOT.jar -o /opt/bedrock-connect/bedrock_connect.jar

adduser bedrockconnect --disabled-password
mkdir -p /etc/supervisor/conf.d

cat >/opt/bedrock-connect/servers.json <<EOF
[
]
EOF

cat >/etc/supervisor/conf.d/bedrock_connect.conf <<EOF
[program:BedrockConnect]
command=/usr/bin/java -jar /opt/bedrock-connect/bedrock_connect.jar nodb=true custom_servers=/opt/bedrock-connect/servers.json featured_servers=false
directory=/opt/bedrock-connect/
autorestart=true
autostart=true
stopasgroup=true
user=bedrockconnect
EOF
rc-service supervisor start
supervisorctl start BedrockConnect
msg_ok "Installed Bedrock Connect $BEDROCK_CONNECT_LATEST_VERSION"

motd_ssh
customize

SERVER_ADDR="$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d "/" -f 1)"

msg_ok "Installed Bedrock Connect"
msg_ok "Connect to $SERVER_ADDR"