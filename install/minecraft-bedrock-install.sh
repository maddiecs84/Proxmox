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
$STD apk add newt
$STD apk add curl
$STD apk add openssh
$STD apk add nano
$STD apk add mc
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
$STD apk add docker
$STD rc-service docker start
$STD rc-update add docker default
msg_ok "Installed Docker"

msg_info "Starting Minecraft Bedrock"
while (! docker stats --no-stream ); do
  # Docker takes a few seconds to initialize
  echo "Waiting for Docker to launch..."
  sleep 1
done
$STD docker run -d -it -e EULA=TRUE -p 19132:19132/udp -v mc-bedrock-data:/data itzg/minecraft-bedrock-server
msg_ok "Started Minecraft Bedrock"

motd_ssh
customize
msg_ok "Installed Minecraft Bedrock"