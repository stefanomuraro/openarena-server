#!/bin/bash

set -e
shopt -s nullglob

: "${UID:=1000}"
: "${GID:=1000}"
: "${SKIP_CHOWN_DATA:=false}"
: "${PUBLIC:=false}"

mkdir -p /data/config /data/maps

if [ "$(id -u)" = 0 ]; then
  usermod -u "$UID" openarena
  groupmod -o -g "$GID" openarena
fi

for file in /tmp/defaults/*; do
  filename="${file##*/}"
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
mkdir -p "/home/openarena/.openarena/baseoa/$log_dir"
rm -f "/home/openarena/.openarena/baseoa/$log"
ln -sfn "/data/$log" "/home/openarena/.openarena/baseoa/$log"

if [ "$(id -u)" = 0 ]; then
  chown -R openarena:openarena /home/openarena/.openarena

  if [ "${SKIP_CHOWN_DATA^^}" != "TRUE" ] && [ "$(stat -c %u /data)" != "$UID" ]; then
    chown -R openarena:openarena /data
  fi
fi

case "${PUBLIC,,}" in
true) dedicated=2 ;;
false) dedicated=1 ;;
*)
  echo "error: PUBLIC must be true or false (got '$PUBLIC')" >&2
  exit 1
  ;;
esac

exec gosu openarena:openarena \
  /opt/openarena/oa_ded.arm \
  +set dedicated "$dedicated" \
  +exec server.cfg
