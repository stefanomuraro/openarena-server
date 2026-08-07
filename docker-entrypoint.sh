#!/bin/bash

set -e
shopt -s nullglob

mkdir -p /data/config /data/maps

for file in /tmp/defaults/*; do
    filename=$(basename "$file")
    cp -n "$file" "/data/config/$filename"
    ln -sfn "/data/config/$filename" "/opt/openarena/baseoa/$filename"
done

for file in /data/maps/*.pk3; do
    ln -sfn "$file" /opt/openarena/baseoa/
done

log=$(grep -w 'g_log' /data/config/server.cfg | awk -F'"' '{print $2}')
log=${log:-server.log}
log_dir=$(dirname "$log") 

mkdir -p "/data/$log_dir" && touch "/data/$log"
mkdir -p "/root/.openarena/baseoa/$log_dir"
rm -f "/root/.openarena/baseoa/$log"
ln -sfn "/data/$log" "/root/.openarena/baseoa/$log"

exec /opt/openarena/oa_ded.arm \
  +set dedicated 2 \
  +exec server.cfg
