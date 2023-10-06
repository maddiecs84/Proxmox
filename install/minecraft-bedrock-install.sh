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

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}
DOCKER_COMPOSE_LATEST_VERSION=$(get_latest_release "docker/compose")

msg_info "Installing Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -sSL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_LATEST_VERSION/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
msg_ok "Installed Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"

cat >/root/config.yml <<EOF
containers:
  bedrock:
    # Backup the world "PrivateSMP" on the "bedrock_server" docker container
    - name: bedrock_server
      worlds:
        - /server/worlds/MyWorld
schedule:
  # This will perform a backup every 3 hours.
  # At most this will generate 8 backups a day.
  interval: 3h
trim:
  # Keep all backups for the last two days (today and yesterday)
  # Keep at least one backup for the last 14 days
  # Keep at least two backups per world
  trimDays: 2
  keepDays: 14
  minKeep: 2
EOF

cat >/root/minecraft-bedrock.yaml <<EOF
version: '3.8'

services:
  backup:
    image: kaiede/minecraft-bedrock-backup
    restart: always
    depends_on:
      - "bedrock-server"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/bedrock/backups:/backups
      - /opt/bedrock/server:/server
      - ${PWD}/config.yml:/backups/config.yml

  bedrock-server:
    image: itzg/minecraft-bedrock-server
    environment:
      EULA: "TRUE"
      GAMEMODE: survival
      DIFFICULTY: normal
      LEVEL_NAME: "MyWorld"
    ports:
      - 19132:19132/udp
    volumes:
      - /opt/bedrock/server:/data
    stdin_open: true
    tty: true
    restart: unless-stopped
EOF

$DOCKER_CONFIG/cli-plugins/docker-compose -f /root/minecraft-bedrock.yaml up --detach

motd_ssh
customize
msg_ok "Installed Minecraft Bedrock"