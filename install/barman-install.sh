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
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y ca-certificates
$STD apt-get install -y wget
$STD apt-get install -y gnupg2
msg_ok "Installed Dependencies"

$STD bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main" >> /etc/apt/sources.list.d/pgdg.list' \
	&& (wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -) \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		cron \
		gcc \
		libpq-dev \
		libpython3-dev \
		openssh-client \
		postgresql-client-9.5 \
		postgresql-client-9.6 \
		postgresql-client-10 \
		postgresql-client-11 \
		postgresql-client-12 \
		postgresql-client-13 \
		postgresql-client-14 \
		postgresql-client-15 \
		postgresql-client-16 \
		python3 \
        python3-distutils \
		rsync \
        gettext-base \
        procps \
        barman \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /etc/crontab /etc/cron.*/* \
	&& sed -i 's/\(.*pam_loginuid.so\)/#\1/' /etc/pam.d/cron \
    && mkdir -p /etc/barman/barman.d

install -d -m 0700 -o barman -g barman ~barman/.ssh
su - barman bash -c 'echo -e "Host *\n\tCheckHostIP no" > ~/.ssh/config'

# TODO: This should be asked during installation
BARMAN_CRON_SRC=/private/cron.d
BARMAN_DATA_DIR=/var/lib/barman
BARMAN_LOG_DIR=/var/log/barman
BARMAN_SSH_KEY_DIR=/private/ssh
BARMAN_CRON_SCHEDULE="* * * * *"
BARMAN_BACKUP_SCHEDULE="0 4 * * *"
BARMAN_LOG_LEVEL=INFO
DB_HOST=pg
DB_PORT=5432
DB_SUPERUSER=postgres
DB_SUPERUSER_PASSWORD=postgres
DB_SUPERUSER_DATABASE=postgres
DB_REPLICATION_USER=standby
DB_REPLICATION_PASSWORD=standby
DB_SLOT_NAME=barman
DB_BACKUP_METHOD=postgres
BARMAN_EXPORTER_SCHEDULE="*/5 * * * *"
BARMAN_EXPORTER_LISTEN_ADDRESS="0.0.0.0"
BARMAN_EXPORTER_LISTEN_PORT=9780
BARMAN_EXPORTER_CACHE_TIME=3600

msg_info "Setting ownership/permissions on ${BARMAN_DATA_DIR} and ${BARMAN_LOG_DIR}"

install -d -m 0700 -o barman -g barman ${BARMAN_DATA_DIR}
install -d -m 0755 -o barman -g barman ${BARMAN_LOG_DIR}

msg_info "Generating Barman configurations"

cat | envsubst >/etc/barman.conf <<EOF
; Commented lines show the default values

[barman]
; archiver = off
backup_method = rsync
; backup_directory = %(barman_home)s/%(name)s

backup_options = concurrent_backup

; This must be set to the BARMAN_DATA_DIR environment variable
barman_home = ${BARMAN_DATA_DIR}

barman_user = barman

; barman_lock_directory = %(barman_home)s
compression = gzip
configuration_files_directory = /etc/barman/barman.d
last_backup_maximum_age = 1 week
minimum_redundancy = 1
;network_compression = true
retention_policy = RECOVERY WINDOW of 3 MONTHS
; retention_policy_mode = auto
;reuse_backup = link
streaming_archiver = on
; wal_retention_policy = main

; use empty log_file for stderr output
log_file = ""
log_level = ${BARMAN_LOG_LEVEL}
EOF

cat | envsubst >/etc/barman/barman.d/pg.conf <<EOF
[${DB_HOST}]
active = true
description =  "PostgreSQL Database (Streaming-Only)"
conninfo = host=${DB_HOST} user=${DB_SUPERUSER} dbname=${DB_SUPERUSER_DATABASE} port=${DB_PORT}
streaming_conninfo = host=${DB_HOST} user=${DB_REPLICATION_USER} port=${DB_PORT}
backup_method = ${DB_BACKUP_METHOD}
streaming_archiver = on
slot_name = ${DB_SLOT_NAME}
EOF

echo "${DB_HOST}:${DB_PORT}:*:${DB_SUPERUSER}:${DB_SUPERUSER_PASSWORD}" > /home/barman/.pgpass
echo "${DB_HOST}:${DB_PORT}:*:${DB_REPLICATION_USER}:${DB_REPLICATION_PASSWORD}" >> /home/barman/.pgpass
chown barman:barman /home/barman/.pgpass
chmod 600 /home/barman/.pgpass

echo "Checking/Creating replication slot"
# barman replication-status ${DB_HOST} --minimal --target=wal-streamer | grep barman || barman receive-wal --create-slot ${DB_HOST}
# barman replication-status ${DB_HOST} --minimal --target=wal-streamer | grep barman || barman receive-wal --reset ${DB_HOST}

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"